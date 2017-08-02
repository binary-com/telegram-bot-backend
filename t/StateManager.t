use strict;
use warnings;

use Test::More "no_plan";
use Binary::TelegramBot::StateManager qw(set_table create_table insert update get disconnect row_exists remove_table sanitize);
use Data::Dumper;

sub start {
    set_table("testtable");
    remove_table();    
    create_table();
    insert(
        1, "abcd",
        {
            loginid  => "1234",
            currency => "USD",
            balance  => 500
        });    
    # check_sanitizer();
}

sub check_sanitizer {
    ok(sanitize(1234) == 1234);
    ok(sanitize("abcd'") eq "abcd");
    ok(sanitize('abcd"') eq "abcd");
    # Normal array
    my @array = @{sanitize(['abcd"', "1234'", 2])};
    ok($array[0] eq 'abcd');
    ok($array[1] eq '1234');
    ok($array[2] == 2);
    # Array in Array
    @array = @{sanitize([1, ["abcd'", ["xyz'"]]])};
    ok($array[1][0] eq 'abcd');
    ok($array[1][1][0] eq 'xyz');
    # Hash in an array
    @array = @{sanitize([1, {a => "abcd'"}])};
    ok($array[1]->{a} eq "abcd");
    # Array in a hash
    my $hash = sanitize({a => ['abcd"', 'xyz"']});
    ok($hash->{a}->[0] eq "abcd");
    ok($hash->{a}->[1] eq "xyz");
}

start();
