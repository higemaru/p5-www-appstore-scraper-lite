use inc::Module::Install;
name 'WWW-AppStore-Scraper-Lite';
author 'KAWABATA, Kazumichi (Higemaru) <kawabata@cpan.org>';
perl_version '5.008';
all_from 'lib/WWW/AppStore/Scraper/Lite.pm';

test_requires 'Test::Base';

requires 'LWP::UserAgent';
requires 'XML::Simple';
requires 'JSON';

WriteAll;
