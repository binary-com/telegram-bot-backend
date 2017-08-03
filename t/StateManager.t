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
    insert(
        2, "xyz",
        {
            loginid  => "567",
            currency => "USD",
            balance  => 1000
        });
    # Get single field.
    my @result = get(1, "loginid");
    ok($result[0] eq "1234");
    # Get multiple fields
    @result = get(1, ["loginid", "currency"]);
    ok($result[0] eq '1234');
    ok($result[1] eq 'USD');
    # Get all fields
    @result = get(2);
    ok($result[0] == 2);
    ok($result[1] eq "xyz");
    ok($result[2] eq "567");
    ok($result[3] eq "USD");
    ok($result[4] == 1000);
    # Check if row already exists
    ok(row_exists(1) == 1);
    update(1, "balance", 1000);
    @result = get(1, "balance");
    ok($result[0] == 1000);
    check_sanitizer();
}

sub check_sanitizer {
    ok(sanitize(1234) == 1234);
    ok(sanitize("abcd'") eq "abcd\\'");
    ok(sanitize('abcd"') eq "abcd\\\"");
    # Normal array
    my @array = @{sanitize(['abcd"', "1234'", 2])};
    ok($array[0] eq 'abcd\\"');
    ok($array[1] eq '1234\\\'');
    ok($array[2] == 2);
    # Array in Array
    @array = @{sanitize([1, ["abcd'", ["xyz'"]]])};
    ok($array[1][0] eq 'abcd\\\'');
    ok($array[1][1][0] eq 'xyz\\\'');
    # Hash in an array
    @array = @{sanitize([1, {a => "abcd'"}])};
    ok($array[1]->{a} eq "abcd\\'");
    # Array in a hash
    my $hash = sanitize({a => ['abcd"', 'xyz"']});
    ok($hash->{a}->[0] eq "abcd\\\"");
    ok($hash->{a}->[1] eq "xyz\\\"");
}

start();
