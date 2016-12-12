# Test HTTP Scenarios

This is a very simple tool developped using shell & perl and allowing you to make HTTP Tests Scenarios.

You define your tests using a describing format split in 3 parts :

- Test description tags and Target URL
- The Request HTTP in plain text
- The elements you want the script to check in the Response.

[![](https://images.microbadger.com/badges/version/sebmoule/http-tests.svg)](http://microbadger.com/images/sebmoule/http-tests "Get your own version badge on microbadger.com") [![](https://images.microbadger.com/badges/image/sebmoule/http-tests.svg)](http://microbadger.com/images/sebmoule/http-tests "Get your own image badge on microbadger.com")

[![Docker Hub](https://img.shields.io/badge/docker-ready-blue.svg)](https://hub.docker.com/r/sebmoule/http-tests/) [![Docker Pulls](https://img.shields.io/docker/pulls/sebmoule/http-tests.svg?maxAge=2592000)]() [![Docker Stars](https://img.shields.io/docker/stars/sebmoule/http-tests.svg?maxAge=2592000)]()


## How to uses

To ease the usage the test-http tool is embedded in a docker.

By default, test-http will try to execute ALL tests `xxx.conf` in ALL `conf/*` directories.

### Default Scenario

test-http is shipped with a DEMO tests which is stored inside `/tests/conf/DEMO` and named `test_001_google.conf`, which makes some requests to google

```
$ docker run --rm sebmoule/http-tests
...
...
You're executing : /test/tests/test_http.sh -d ALL -t ALL
working on test : ALL in directory DEMO from  DEMO
=> DEMO conf/DEMO/test_001_google.conf  OK  ()
	Result Step 1:1  Validation :  200 OK + Token [OK] (0 ms)
		Result Step 2:1  Validation :  200 OK + Token [OK] (-1 ms)
			Result Step 3:1  Validation :  301 on www.google.fr [OK] (0 ms)
				Result Step 4:1  Validation :  200 OK  [OK] (0 ms)
DEMO : Nb test : 4 Nb Check OK: 7 Nb Checks KO : 0
Number of request tested 4  Nb Check OK: 7 Nb Checks KO : 0:
```

This as Executed the demo test which is composed of 4 Steps, and it output the result.

### View the Details of execution

You can either mount the result directory locally or inspect the container to see details logs :

```
$ docker run --rm -v /tmp/results:/test/tests/results sebmoule/http-tests

$ tree /tmp/results/
/tmp/results/
|-- Global_result_ALL_DEMO.txt
`-- result_ALL_DEMO
    `-- DEMO
	        |-- detailed.log
	        `-- result.txt
```

The Detail Result is the file `/tmp/results/result_ALL_DEMO/DEMO/detailed.log`

If There was many config file there will be many results

```
$ docker run -ti --rm \
	-v $PWD/test_002_google.conf:/test/conf/TEST/test_002_google.conf \
	-v /tmp/results:/test/tests/results \
	sebmoule/http-tests

$ tree /tmp/results/
/tmp/results/
|-- Global_result_ALL_DEMO.txt
|-- html
`-- result_ALL_DEMO
    |-- DEMO
    |   |-- detailed.log
	    |   `-- result.txt
    `-- TEST
        |-- detailed.log
	        `-- result.txt
```								


### Filter which directory to execute

We can use a Filter to specify which Test directory execute (default is the keyword `ALL`) using the Environnement Variable `DIR` which must specify a directory in `/tests/conf`


```
$ docker run -ti --rm \
	-v $PWD/test_002_google.conf:/test/conf/TEST/test_002_google.conf \
	-v /tmp/results:/test/tests/results \
	-e DIR=TEST \
	sebmoule/http-tests

$ tree /tmp/results/
/tmp/results/
|-- Global_result_ALL_TEST.txt
`-- result_ALL_TEST
    `-- TEST
        |-- detailed.log
        `-- result.txt
```								


### Filter which test to execute

We can use a Filter to specify which Test to execute within a directory (default is the keyword `ALL`) using the Environnement Variable `TEST` which must specify a valide `*.conf` file in `/tests/conf/$DIR/`


```
$ docker run -ti --rm \
	-v $PWD/test_002_google.conf:/test/conf/DEMO/test_002_google.conf \
	-v /tmp/results:/test/tests/results \
	-e DIR=DEMO \
	-e TEST=002 \
	sebmoule/http-tests
```

This will only execute tests in `conf/DEMO/test_002_google.conf`

```
You're executing : /test/tests/test_http.sh -d DEMO -t 002 -p DEV
working on test : 002 in directory DEMO from DEMO
=> DEMO conf/DEMO/test_002_google.conf  OK  ()
	Result Step 1:1  Validation :  200 OK + Token [OK] (-1 ms)
	Result Step 2:1  Validation :  200 OK + Token [OK] (0 ms)
	Result Step 3:1  Validation :  301 on www.google.fr [OK] (0 ms)
	Result Step 4:1  Validation :  200 OK  [OK] (0 ms)
DEMO : Nb test : 4 Nb Check OK: 7 Nb Checks KO : 0 . Detailed Test log : results/result_002_DEMO/DEMO/detailed.log
```

## Using Tag File

You can specify Tag file which will contain basic KEY=VALUE items, allowing you to dynamically change your `*.conf` files depending on target.

You can have a single generic .conf file which can be executed with a DEV Tag file and with a PROD Tag file.

The default TAG file is `/tests/tags/TAGS_FILE_DEV`. The `DEV` part is the default and you can change it using the `PLATEFORME` environment variable

ex of tags:
```
$ cat tags/TAGS_FILE_DEV
<MAVAR>=TEST
<SERVER>=www.google.fr
```

ex of usage in the .conf file :

```
##URLTEST=https://<SERVER>
GET / HTTP/1.1
User-Agent: curl/7.35.0
Host: <SERVER>
Accept: */*
---
HTTP/1.1 200 OK
--------------------
```

this will call https://www.google.fr with request :

```
GET / HTTP/1.1
User-Agent: curl/7.35.0
Host: www.google.fr
Accept: */*
```

The script will be OK if it found `HTTP/1.1 200 OK` in the response.


## Advanced Checks of requests

You can define Rexexp to check in the response and this allow you to capture variables you can reuses in next requests.
Reuse of variables works only in the same scénario (.conf file).

- if the check line starts with `_$_` then we are in Regexp mode
  - in the previous Example we chack that the response contains the value `Location: http://www.google.fr/` because the `<SERVER>` tag is `www.google.fr`
    - If the responses don't Match that line, then the Test will be KO and we will go to next checks
	- If the response Match, we will apply the regexp
      - after what we want to match we set 2 pipes `||` and then a list of variables names separated by space.
        - according to the regexp parenthesis, the variables will be populated
	    - thoses variables will be accessible through special tag `<STEPX_varname>` where X is the step Number where the values are store and varname is the name of the variable store.
	
example test.conf:
```
##URLTEST=http://<SERVER>
GET / HTTP/1.1
User-Agent: curl/7.35.0
Host: google.fr
Accept: */*
---
HTTP/1.1 301 Moved Permanently
_$_ Location: (http://(<SERVER>))(/) || url host uri
--------------------
```

The output of the script when executing this test will be :

```
Step 3:1  Validation :  If there is no www. there will be a redirect on it (method="GET")-->
Validation Test : [  OK   ] HTTP/1.1 301 Moved Permanently
Validation Test : [  OK   ] Location: (http://(www.google.fr))(/) found (backup data : url (http://www.google.fr))
Validation Test : [  OK   ] Location: (http://(www.google.fr))(/) found (backup data : host (www.google.fr))
Validation Test : [  OK   ] Location: (http://(www.google.fr))(/) found (backup data : uri (/))
```
It says test is OK and specify what var it has created

We can reuse those var in Nexts steps :

```
##URLTEST=<STEP1_url>
GET <STEP1_uri> HTTP/1.1
User-Agent: curl/7.35.0
Host: <STEP1_host>
Accept: */*
---
HTTP/1.1 200 OK
--------------------
```

- So, when calling in the Next Step, `<STEP1_url>` it will be the value `http://www.google.fr`
- So, when calling in the Next Step, `<STEP1_host>` it will be the value `www.google.fr`
- So, when calling in the Next Step, `<STEP1_uri>` it will be the value `/`


## Alternatives

You can Use Jmeter, Robot Framework

This tools may also be useful : https://github.com/lifeforms/httpcheck
