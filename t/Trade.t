use strict;
use warnings;

use Test::More "no_plan";
use Binary::TelegramBot::Modules::Trade qw(get_trade_type process_trade get_payout_keyboard);

my $response;

sub start {
    testPayoutKeyboard();
    test1();
    testProcessTrade();
}

sub testPayoutKeyboard {
    my $args = ['DIGITEVEN', 'R_10', '', '5'];
    my @keys = @{get_payout_keyboard($args, 'USD')};
    ok($keys[0]->[0] eq '5 USD', 'Check for USD');
    @keys = @{get_payout_keyboard($args, 'BTC')};
    ok($keys[0]->[0] eq '0.001 BTC', 'Check for BTC');
}

sub test1 {
    my $resp = get_trade_type("DIGITMATCH");
    ok($$resp[0] eq "Digit Matches", "Trade type shortcode to longcode");
    $resp = get_trade_type("DIGITMATCH_5");
    my $expected_resp = ["Digit Matches", 5];
    is_deeply($resp, $expected_resp, "Trade type with barrier, response");
}

sub testProcessTrade {
    my $keyboard = process_trade("", "USD");
    #use Data::Dumper; print Dumper $keyboard;
    is(scalar @{$keyboard->[0]->{reply_markup}->{inline_keyboard}}, 13, "Initial response for trade command");
    $keyboard = process_trade("DIGITEVEN   ", "USD");
    is($keyboard->[0]->{reply_markup}->{inline_keyboard}->[5]->[0]->{callback_data}, "/trade DIGITEVEN R_50  ", "Check if trade_type is appended to callback data");
    $keyboard = process_trade("DIGITEVEN R_10  ", "USD");
    is($keyboard->[0]->{reply_markup}->{inline_keyboard}->[8]->[0]->{callback_data}, "/trade DIGITEVEN R_10 5 ", "Check if underlying is appended to the callback_data");
    $keyboard = process_trade("DIGITEVEN R_10 5 ", "USD");
    is($keyboard->[0]->{reply_markup}->{inline_keyboard}->[11]->[0]->{callback_data}, "/trade DIGITEVEN R_10 5 5", "Check if currency is appended to the callback_data");
    $keyboard = process_trade("DIGITEVEN R_10 5 ", "USD");
    is($keyboard->[0]->{reply_markup}->{inline_keyboard}->[2]->[1]->{text}, "\x{2705} Digit Even", "Check if trade_type was highlighted.");
    is($keyboard->[0]->{reply_markup}->{inline_keyboard}->[4]->[0]->{text}, "\x{2705} Volatility Index 10", "Check if underlying was highlighted.");
    is($keyboard->[0]->{reply_markup}->{inline_keyboard}->[8]->[0]->{text}, "\x{2705} 5 USD", "Check if currency was highlighted.");
    $keyboard = process_trade("DIGITEVEN R_10  6", "USD");
    is($keyboard->[0]->{reply_markup}->{inline_keyboard}->[11]->[1]->{text}, "\x{2705} 6 ticks", "Check if ticks was highlighted.");
    $keyboard = process_trade("DIGITMATCH_6 R_10 5 ", "USD");
    is($keyboard->[0]->{reply_markup}->{inline_keyboard}->[5]->[1]->{text}, "\x{2705} 6", "Check if barrier was highlighted");
    my $proposal = process_trade("DIGITMATCH_6 R_10 5 6", "USD");
    ok($proposal->[1]->{proposal}, "Proposal request is returned if all the options are selected");
    $proposal = process_trade("DIGITMATCH R_10 5 6", "USD");
    is($proposal->[1]->{proposal}, undef, "Proposal is not returned if barrier is not selected");
}

start();
