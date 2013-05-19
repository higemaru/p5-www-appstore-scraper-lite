package WWW::AppStore::Scraper::Lite;

use strict;
use utf8;
use warnings;

use LWP::UserAgent;
use XML::Simple;
use JSON;

our $VERSION = '0.12';

sub new {
    my $class = shift;
    my @args = @_;
    my $args_ref = ref $args[0] eq 'HASH' ? $args[0] : {@args};

    my $self = bless{}, ref $class || $class;

    $self->{__STORE_CODES} = _init_countries();

    $self->{ua} = LWP::UserAgent->new();
    $self->{ua}->timeout(30);
    $self->{ua}->env_proxy;
    $self->{ua}->agent( __PACKAGE__ );
    $self->{__WAIT} = $args_ref->{wait} || '1';

#    $self->{__XML_PREFERRED_PARSER} = 'XML::SAX::PurePerl';
    $self->{__XML_PREFERRED_PARSER} = 'XML::Parser';
#    $self->{__XML_PREFERRED_PARSER} = 'XML::SAX::Expat';
#    $self->{__XML_PREFERRED_PARSER} = 'XML::LibXML::SAX';

    $self;
}

sub app_info {
    my $self = shift;
    my @args = @_;

    # get info from app page
    my $base = $self->app_base_info( @args );

    my $ret = {};
    for my $app ( keys %$base ) {
        for my $store ( keys %{$base->{$app}} ) {
            my $info = $base->{$app}->{$store};
            next unless $info->{genre_id};

            my $reviews = $self->app_reviews(
                                             app => $app,
                                             info => $info,
                                            );
            $ret->{$app}->{$store} = {
                                      %$info,
                                      reviews => $reviews,
                                      store_name => $self->{__STORE_CODES}->{$store}->{name},
                                     };
            sleep $self->{__WAIT};
        }
    }

    $ret;
}

sub app_base_info {
    my $self = shift;
    my @args = @_;

    my $args = $self->_validate_args(@args);

    my $ret = {};
    for my $app ( @{$args->{apps}} ) {
        for my $store ( keys %{$args->{stores}} ) {
            my $uri = 'http://ax.itunes.apple.com/WebObjects/MZStoreServices.woa/wa/wsLookup?id='.$app.'&entity=software&country='.$store;
            my $hash = $self->_get_json( $uri );
	    next unless ( exists $hash->{results} and exists $hash->{results}->[0] );
	    my $info = $hash->{results}->[0];
            $ret->{$app}->{$store} = {
				      store_code => $args->{stores}->{$store}->{code},
				      review_number => $args->{review_number},
				      store => $store,

				      genre_id => $info->{primaryGenreId},
				      artist_id => $info->{artistId},
				      app_name => $info->{trackName},
				      genre_name => $info->{primaryGenreName},
				      price => $info->{price},
				     };

	    $ret->{$app}->{$store}->{app_name} =~ s/^\s+(.*)\s+$/$1/;
	    for my $k (
		       'averageUserRating',
		       'userRatingCount',
		       'averageUserRatingForCurrentVersion',
		       'userRatingCountForCurrentVersion'
		      ) {
		$ret->{$app}->{$store}->{ratings}->{$k} = $info->{$k};
	    }
        }
    }
    $ret;
}


#
# for reviews
#

sub app_reviews {
    my $self = shift;
    my @args = @_;

    my $args_ref = ref $args[0] eq 'HASH' ? $args[0] : {@args};
    my $ret = [];

    my $info;
    if ( $args_ref->{info} ) {
        $info = $args_ref->{info};
    }
    else {
        my $base_info = $self->app_base_info($args_ref);
        $info = $base_info->{ $args_ref->{app} }->{ $args_ref->{store} };
    }

    my $uri = 'http://itunes.apple.com/' . $info->{store}.'/rss/customerreviews/id=' . $args_ref->{app} . '/sortBy=mostRecent/xml';

    my $rss = $self->_get_xml( $uri );
    if ( exists $rss->{entry} and ref( $rss->{entry} ) eq 'ARRAY' ) {
        shift @{$rss->{entry}};
        for my $review ( @{$rss->{entry}} ) {
            next unless ( exists $review->{content} and ref($review->{content}) eq 'ARRAY' );
            my $message = '';
            for my $mes ( @{$review->{content}} ) {
                if ( $mes->{type} eq 'text' ) {
                    $message = $mes->{content};
                    last;
                }
            }
            my @tmps = split /T/, $review->{updated};
            push @$ret, {
                         title => $review->{title},
                         message => $message,
                         date => $tmps[0],
                        };
            last if scalar(@$ret) >= $info->{review_number};
        }
    }

    $ret;
}


#
# common
#

sub _validate_args {
    my $self = shift;
    my @args = @_;

    my $args_ref = ref $args[0] eq 'HASH' ? $args[0] : {@args};

    #
    # prepare array by target apps
    #

    die 'app code MUST be needed' unless $args_ref->{app};

    my @appcode = ref $args_ref->{app} eq 'ARRAY' ? @{$args_ref->{app}}
        : ($args_ref->{app});
    for (@appcode) {
        die 'app code MUST be numerical: ',$_ unless m|^\d+$|;
    }
    my $apps_array = [@appcode];

    #
    # prepare array by target countries
    #

    my $stores_hash;
    if ( $args_ref->{store} ) {
        my @storename = ref $args_ref->{store} eq 'ARRAY' ? @{$args_ref->{store}}
            : ($args_ref->{store});
        for ( @storename ) {
            my $s = lc $_;
            if ( exists $self->{__STORE_CODES}->{ $s } ) {
                $stores_hash->{ $s } = $self->{__STORE_CODES}->{ $s };
            }
            else {
                die 'cannot found appstore on "', $s, '"';
            }
        }
    }
    else {
        $stores_hash = $self->{__STORE_CODES};
    }

    #
    # prepare reviews max number
    #

    my $review_number = ( exists $args_ref->{review_number} and $args_ref->{review_number} =~ /^\d+$/ ) ? $args_ref->{review_number} :25;

    return {
            apps => $apps_array,
            stores => $stores_hash,
            review_number => $review_number,
           };
}

sub _get_json {
    my $self = shift;
    my $uri = shift;

    my $res = $self->{ua}->get( $uri );

    # Error Check
    unless ( $res->is_success ) {
        warn 'request failed: ', $uri, ': ', $res->status_line;
        return;
    }
    my $jsondata = $res->content;
    if ( utf8::is_utf8($jsondata) ) {
        utf8::encode($jsondata);
    }

    my $hash;
    my $json = JSON->new->utf8;
    eval { $hash = $json->decode($jsondata) };

    return $hash;
}

sub _get_xml {
    my $self = shift;
    my $uri = shift;

    my $res = $self->{ua}->get( $uri );

    # Error Check
    unless ( $res->is_success ) {
        warn 'request failed: ', $uri, ': ', $res->status_line;
        return;
    }
    unless ( $res->headers->header('Content-Type') =~ m|/xml| ) {
        warn 'content is not xml: ', $uri, ': ', $res->headers->header('Content-Type');
        return;
    }
    local $XML::Simple::PREFERRED_PARSER = $self->{__XML_PREFERRED_PARSER};
    my $xmlobj = XMLin( $res->content );

    $xmlobj;
}

sub _init_countries {

    my $c = {
             jp => {
                    name => 'Japan',
                    code => 143462,
                   },
             us => {
                    name => 'United States',
                    code => 143441,
                   },
             ar => {
                    name => 'Argentine',
                    code => 143505,
                   },
             au => {
                    name => 'Autstralia',
                    code => 143460,
                   },
             be => {
                    name => 'Belgium',
                    code => 143446,
                   },
             br => {
                    name => 'Brazil',
                    code => 143503,
                   },
             ca => {
                    name => 'Canada',
                    code => 143455,
                   },
             cl => {
                    name => 'Chile',
                    code => 143483,
                   },
             cn => {
                    name => 'China',
                    code => 143465,
                   },
             co => {
                    name => 'Colombia',
                    code => 143501,
                   },
             cr => {
                    name => 'Costa Rica',
                    code => 143495,
                   },
             hr => {
                    name => 'Croatia',
                    code => 143494,
                   },
             cz => {
                    name => 'Czech Republic',
                    code => 143489,
                   },
             dk => {
                    name => 'Denmark',
                    code => 143458,
                   },
             de => {
                    name => 'Germany',
                    code => 143443,
                   },
             sv => {
                    name => 'El Salvador',
                    code => 143506,
                   },
             es => {
                    name => 'Spain',
                    code => 143454,
                   },
             fi => {
                    name => 'Finland',
                    code => 143447,
                   },
             fr => {
                    name => 'France',
                    code => 143442,
                   },
             gr => {
                    name => 'Greece',
                    code => 143448,
                   },
             gt => {
                    name => 'Guatemala',
                    code => 143504,
                   },
             hk => {
                    name => 'Hong Kong',
                    code => 143463,
                   },
             hu => {
                    name => 'Hungary',
                    code => 143482,
                   },
             in => {
                    name => 'India',
                    code => 143467,
                   },
             id => {
                    name => 'Indonesia',
                    code => 143476,
                   },
             ie => {
                    name => 'Ireland',
                    code => 143449,
                   },
             il => {
                    name => 'Israel',
                    code => 143491,
                   },
             it => {
                    name => 'Italia',
                    code => 143450,
                   },
             kr => {
                    name => 'Korea',
                    code => 143466,
                   },
             kw => {
                    name => 'Kuwait',
                    code => 143493,
                   },
             lb => {
                    name => 'Lebanon',
                    code => 143497,
                   },
             lu => {
                    name => 'Luxembourg',
                    code => 143451,
                   },
             my => {
                    name => 'Malaysia',
                    code => 143473,
                   },
             mx => {
                    name => 'Mexico',
                    code => 143468,
                   },
             nl => {
                    name => 'Nederland',
                    code => 143452,
                   },
             nz => {
                    name => 'New Zealand',
                    code => 143461,
                   },
             no => {
                    name => 'Norway',
                    code => 143457,
                   },
             at => {
                    name => 'Osterreich',
                    code => 143445,
                   },
             pk => {
                    name => 'Pakistan',
                    code => 143477,
                   },
             pa => {
                    name => 'Panama',
                    code => 143485,
                   },
             pe => {
                    name => 'Peru',
                    code => 143507,
                   },
#             ph => {
#                    name => 'Phillipines',
#                    code => 143474,
#                   },
             pl => {
                    name => 'Poland',
                    code => 143478,
                   },
             pt => {
                    name => 'Portugal',
                    code => 143453,
                   },
             qa => {
                    name => 'Qatar',
                    code => 143498,
                   },
             ro => {
                    name => 'Romania',
                    code => 143487,
                   },
             ru => {
                    name => 'Russia',
                    code => 143469,
                   },
             sa => {
                    name => 'Saudi Arabia',
                    code => 143479,
                   },
             ch => {
                    name => 'Switzerland',
                    code => 143459,
                   },
             sg => {
                    name => 'Singapore',
                    code => 143464,
                   },
             sk => {
                    name => 'Slovakia',
                    code => 143496,
                   },
             si => {
                    name => 'Slovenia',
                    code => 143499,
                   },
             za => {
                    name => 'South Africa',
                    code => 143472,
                   },
#             lk => {
#                    name => 'Sri Lanka',
#                    code => 143486,
#                   },
             se => {
                    name => 'Sweden',
                    code => 143456,
                   },
             tw => {
                    name => 'Taiwan',
                    code => 143470,
                   },
#             th => {
#                    name => 'Thailand',
#                    code => 143475,
#                   },
             tr => {
                    name => 'Turkey',
                    code => 143480,
                   },
             ae => {
                    name => 'United Arab Emirates',
                    code => 143481,
                   },
             gb => {
                    name => 'United Kingdom',
                    code => 143444,
                   },
             ve => {
                    name => 'Venezuela',
                    code => 143502,
                   },
             vn => {
                    name => 'Vietnam',
                    code => 143471,
                   },
            };
}

1;
__END__

=head1 NAME

WWW::AppStore::Scraper::Lite - Get software review/rate on AppStore.

=head1 SYNOPSIS

  use WWW::AppStore::Scraper::Lite;
  use Data::Dumper;

  my $obj = WWW::AppStore::Scraper::Lite->new(wait => 5);

  my $info = $obj->app_info(
  			    app => ['404732112'],
			    store => ['jp','us'],
			    review_number => 1,
                           );

  print Dumper $info;

  # result
  # $VAR1 = {
  #           '404732112' => {
  #                            'jp' => {
  #                                      'review_number' => 1,
  #                                      'store' => 'jp',
  #                                      'reviews' => [
  #                                                     {
  #                                                       'date' => '2012-11-05',
  #                                                       'title' => "......",
  #                                                       'message' => "......"
  #                                                     }
  #                                                   ],
  #                                      'store_code' => 143462,
  #                                      'genre_id' => 6002,
  #                                      'app_name' => "Sleipnir Mobile - Web \x{30d6}\x{30e9}\x{30a6}\x{30b6}",
  #                                      'store_name' => 'Japan',
  #                                      'artist_id' => 318578225,
  #                                      'ratings' => {
  #                                                     'userRatingCount' => 1727,
  #                                                     'averageUserRatingForCurrentVersion' => '4.5',
  #                                                     'averageUserRating' => '3.5',
  #                                                     'userRatingCountForCurrentVersion' => 4
  #                                                   },
  #                                      'price' => '0',
  #                                      'genre_name' => 'Utilities'
  #                                    },
  #                            'us' => {
  #                                      'review_number' => 1,
  #                                      'store' => 'us',
  #                                      'reviews' => [
  #                                                     {
  #                                                       'date' => '2012-09-08',
  #                                                       'title' => '......',
  #                                                       'message' => '.......'
  #                                                     }
  #                                                   ],
  #                                      'store_code' => 143441,
  #                                      'genre_id' => 6002,
  #                                      'app_name' => 'Sleipnir Mobile - Web Browser',
  #                                      'store_name' => 'United States',
  #                                      'artist_id' => 318578225,
  #                                      'ratings' => {
  #                                                     'userRatingCount' => 220,
  #                                                     'averageUserRatingForCurrentVersion' => undef,
  #                                                     'averageUserRating' => '4.5',
  #                                                     'userRatingCountForCurrentVersion' => undef
  #                                                   },
  #                                      'price' => '0',
  #                                      'genre_name' => 'Utilities'
  #                                    }
  #                          }
  #         };

=head1 DESCRIPTION

App information is provided Apple Search API (JSON).
App reviews is provided RSS.
WWW::AppStore::Scraper::Lite get both.

=head1 Methods

=head2 new

=over 4

blah blah

=over 4

=item wait

set interval (second). per app, per store.

=back

=back

=head2 app_info

=over 4

Get application information.

=over 4

=item app

set application identifier code.

ex.
  app => '404732112',
  app => ['404732112', '531254369'],
 ......

=item store

set store_code. By default, get info from all country's stores.

NOTE: I suggest you should set one or two store_code.

ex.
  store => 'jp',
  store => ['jp','us'],
  ......

=back

=back

=head2 app_base_info

Get application information without review.

=head1 AUTHORS

KAWABATA, Kazumichi (Higemaru) E<lt>kawabata@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

=head1 SEE ALSO

Search API: L<http://www.apple.com/itunes/affiliates/resources/documentation/itunes-store-web-service-search-api.html>

=cut
