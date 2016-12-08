
build:
	docker build -t sebmoule/http-tests .

run-ash:
	docker run -ti --rm --entrypoint bash sebmoule/http-tests

run:
	docker run -ti --rm sebmoule/http-tests

dependency:
	sudo apt-get install libxml-libxml-perl liblwp-protocol-https-perl
	sudo cpan install LWP::Protocol::http10
