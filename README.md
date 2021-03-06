# NAME

WWW::AppStore::Scraper::Lite - Get software review/rate on AppStore.

# SYNOPSIS

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

# DESCRIPTION

App information is provided Apple Search API (JSON).
App reviews is provided RSS.
WWW::AppStore::Scraper::Lite get both.

# Methods

## new

    blah blah

    - wait

        set interval (second). per app, per store.

## app\_info

    Get application information.

    - app

        set application identifier code.

        ex.
          app => '404732112',
          app => \['404732112', '531254369'\],
         ......

    - store

        set store\_code. By default, get info from all country's stores.

        NOTE: I suggest you should set one or two store\_code.

        ex.
          store => 'jp',
          store => \['jp','us'\],
          ......

## app\_base\_info

Get application information without review.

# AUTHORS

KAWABATA, Kazumichi (Higemaru) <kawabata@cpan.org>

# LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

# SEE ALSO

Search API: [http://www.apple.com/itunes/affiliates/resources/documentation/itunes-store-web-service-search-api.html](http://www.apple.com/itunes/affiliates/resources/documentation/itunes-store-web-service-search-api.html)
