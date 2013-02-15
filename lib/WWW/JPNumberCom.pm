package WWW::JPNumberCom;

use 5.008;
use strict;
use warnings FATAL => 'all';
use utf8;
use Furl;
use HTML::TreeBuilder::XPath;
use Encode;
use Carp;
use URI;

=encoding utf8

=head1 NAME

WWW::JPNumberCom - Perl API of www.jpnumber.com

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use WWW::JPNumberCom;

    my @numbers = WWW::JPNumberCom->search( 'サウナ' );
    my $info = WWW::JPNumberCom->number( $number[0] );
    print $info->{user}{name}. "\n";
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 CLASS VALUE

=head2 AGENT

=cut 

our $AGENT //= Furl->new( agent => __PACKAGE__.'/'.$VERSION );

=head2 BASEURL

=cut

our $BASEURL //= 'http://www.jpnumber.com';

=head1 SUBROUTINES/METHODS

=head2 number

    my $data = WWW::JPNumberCom->number( '0123456789' );

=cut

sub number {
    my ($class, $number) = @_;

    my $data = $class->search($number);
    return unless $data->{total};

    my $url = $data->{numbers}[0]{link};
    my $tree = $class->fetch_url($url);
    my $user_enable = $tree->findnodes('//*[@id="result-main-right"]/div[3]/div[2]/table') ? 1 : 0;
    my $report_exists = $tree->findnodes('//*[@id="result-main-right"]/span/div[3]/div[@class="title-background-pink"]') ? 1 : 0;

    return +{
        number => {
            raw               => $number,
            area_code         => $tree->findvalue('//*[@id="result-main-right"]/div[1]/div[2]/table/tr[1]/td[2]'),
            city_code         => $tree->findvalue('//*[@id="result-main-right"]/div[1]/div[2]/table/tr[1]/td[4]'),
            subscriber_number => $tree->findvalue('//*[@id="result-main-right"]/div[1]/div[2]/table/tr[1]/td[6]'),
            type              => $tree->findvalue('//*[@id="result-main-right"]/div[1]/div[2]/table/tr[3]/td[2]'),
            provider          => $tree->findvalue('//*[@id="result-main-right"]/div[1]/div[2]/table/tr[3]/td[4]'),
        },
        user => $user_enable ? {
            name          => $tree->findvalue('//*[@id="result-main-right"]/div[3]/div[2]/table/tr[1]/td[2]'),
            industry_type => [ split ',', $tree->findvalue('//*[@id="result-main-right"]/div[3]/div[2]/table/tr[2]/td[2]') ],
            address       => $tree->findvalue('//*[@id="result-main-right"]/div[3]/div[2]/table/tr[3]/td[2]'),
            contact_to    => $tree->findvalue('//*[@id="result-main-right"]/div[3]/div[2]/table/tr[4]/td[2]'),
            station_near  => $tree->findvalue('//*[@id="result-main-right"]/div[3]/div[2]/table/tr[5]/td[2]'),
            traffic       => $tree->findvalue('//*[@id="result-main-right"]/div[3]/div[2]/table/tr[6]/td[2]'),
            official_url  => $tree->findvalue('//*[@id="result-main-right"]/div[3]/div[2]/table/tr[7]/td[2]/a/@href'),
        } : undef,
        reports => $report_exists ? [
            map {
                my $node = $_;
                my $reporter = $node->find('span');
                my $date = $node->find_by_attribute('align','right');
                my $body = $node->find('dt');
                +{
                    reporter => $reporter->as_text,
                    date     => $date->as_text,
                    body     => $body->as_text,
                };
            } $tree->findnodes('//*[@id="result-main-right"]/span/div[@class="frame-728-gray-l"]'),
        ] : [],
    };
}


=head2 search

    my @numbers = WWW::JPNumberCom->search($keyword_or_number);

=cut

sub search {
    my ($class, $query, $page) = @_;

    $page ||= 1;
    croak "search query is null" unless $query;

    my $url = URI->new($BASEURL.'/searchnumber.do');
    $url->query_form(number => $query);

    my $tree = $class->fetch_url($url);
    my $total = 0+ $tree->findvalue( '//*[@id="result-main-right-title-l"]/span[2]' );

    return +{
        page          => $page,
        lastpage      => 1+ int($total / 20),
        numbers       => [
            map {
                my $belt = $_->find_by_attribute('class','title-text12');
                my ($num) = $belt->as_text =~ /\(([0-9]+)\)$/;
                my $link = $BASEURL.'/'.$belt->find('a')->attr('href');
                +{
                    number => $num,
                    link   => $link,
                };
            } $tree->findnodes( '//*[@id="result-main-right"]/div[@class="frame-728-orange-l"]' ),
        ],
        links         => [
            map {
                $BASEURL.'/'.$_ ;
            } $tree->findvalues( '//*[@id="result-main-right"]/div[@class="frame-728-orange-l"]/table/tr/td[2]/a/@href' ),
        ],
        total         => $total,
    };
}

=head2 recent_reports 

    my @reports = WWW::JPNumberCom->recent_reports;

=cut

sub recent_reports {
    my ($class) = @_;
    my $url = URI->new($BASEURL.'/newcomment/');
    my $tree = $class->fetch_url($url);
    return [
        map {
            my $number = $_->find_by_attribute('class','result');
            my $who = $_->find_by_attribute('align','right')->as_text;
            my ($reporter, $date) = $who =~ /^(.+)\((.+)\)$/;
            my $summary = $_->find('dt')->as_text;
            $summary =~ s/詳細を見る$//;
            +{
                number   => $number->as_text,
                link     => $BASEURL.$number->attr('href'),
                reporter => $reporter,
                date     => $date,
                summary  => $summary,
            };
        } $tree->findnodes('//*[@id="container"]/div[3]/div[4]/div[1]/div[@class="frame-728-orange-l"]'),
    ];
}

sub fetch_url {
    my ($class, $url) = @_;
    my $res = $AGENT->get($url);
    unless ( $res->is_success ) {
        croak "could not load $url :". $res->status_line;
        return;
    }
    my $tree = HTML::TreeBuilder::XPath->new;
    $tree->parse( Encode::decode_utf8($res->content) );
    return $tree;
}


=head1 AUTHOR

ytnobody, C<< <ytnobody attt gmail> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-jpnumbercom at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-JPNumberCom>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::JPNumberCom


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-JPNumberCom>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-JPNumberCom>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-JPNumberCom>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-JPNumberCom/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013 ytnobody.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of WWW::JPNumberCom
