#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use FindBin;
use lib ("$FindBin::Bin/../lib");
use WWW::JPNumberCom;
use Data::Dumper;

print Dumper( WWW::JPNumberCom->search('ヤマト運輸') );
print Dumper( WWW::JPNumberCom->number('0113303333') );
print Dumper( WWW::JPNumberCom->number('08094161690') );
print Dumper( WWW::JPNumberCom->recent_reports );
