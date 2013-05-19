requires 'JSON';
requires 'LWP::UserAgent';
requires 'XML::Simple';
requires 'perl', '5.008_001';

on build => sub {
    requires 'Test::Base';
};
