use 5.006;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'WWW::JPNumberCom',
    AUTHOR           => q{ytnobody <ytnobody attt gmail>},
    VERSION_FROM     => 'lib/WWW/JPNumberCom.pm',
    ABSTRACT_FROM    => 'lib/WWW/JPNumberCom.pm',
    LICENSE          => 'Artistic_2_0',
    PL_FILES         => {},
    MIN_PERL_VERSION => 5.006,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
        'Furl' => 0,
        'HTML::TreeBuilder::XPath' => 0,
        'Encode' => 0,
        'URI' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
    },
    PREREQ_PM => {
        #'ABC'              => 1.6,
        #'Foo::Bar::Module' => 5.0401,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'WWW-JPNumberCom-*' },
);
