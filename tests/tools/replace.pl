#!/usr/bin/perl
#
# replace.pl
#  
# Made by (sebastien)
# Login   <sallaman@epita.fr>
#
# Started on  Mon Aug 11 11:29:09 2003 sebastien
# Last update Mon Aug 11 11:29:51 2003 sebastien
#

use strict;

die ("Syntaxe: [pattern to search] [replacement] [files...]\n") if @ARGV < 3;

my($search, $replace, @file_list, $file) = @ARGV;

foreach $file (@file_list)
{
    read_content($file, $search, $replace);
}

# read the file content and update file if necessary

sub read_content
{
    my($file, $search, $replace) = @_;
    my $changes = 0;
    my @list = ();
    my($old_line, $new_line);
    my $line = 1;

    @list = ();
    open(FILE, $file) || die ("Cannot read $file: $!\n");
    while ($old_line = <FILE>)
    {
        $new_line = $old_line;
        if ($new_line =~ s/$search/$replace/g)
        {
            $changes++;
        }
        push(@list, $new_line);
        $line++;
    }
    close(FILE);
    write_content($file, @list) if ($changes > 0);
}

sub write_content
{
    my($file, @list) = @_;
    open(FILE, ">$file") || die ("Cannot write $file $!\n");
    print FILE @list;
    close(FILE);
}








