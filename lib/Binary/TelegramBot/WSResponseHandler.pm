package Binary::TelegramBot::WSResponseHandler;

use strict;
use warnings;

use JSON qw(decode_json);
use Binary::TelegramBot::WSBridge qw(get_property);
use POSIX qw(strftime);
use Exporter qw(import);

our @EXPORT = qw(forward_ws_response);

sub forward_ws_response {
    my ($stash, $chat_id, $resp) = @_;
    my $process_ws_resp = {
        "authorize" => \&authorize,
        "balance" => \&balance,
        "buy" => \&buy,
        "error" => \&error,
        "logout" => \&logout,
        "proposal" => \&proposal,
        "proposal_open_contract" => \&proposal_open_contract
    };

    return if !$resp;

    $resp = decode_json($resp);
    $resp = escape_markdown($resp);

    if ($resp->{error}) {
        return $process_ws_resp->{error}->($stash, $chat_id, $resp->{error}->{message});
    } else {
        my $msg_type = $resp->{msg_type};
        return $process_ws_resp->{$msg_type}->($stash, $chat_id, $resp->{$msg_type});
    }
}

sub authorize {
    my ($stash, $chat_id, $resp) = @_;
    my $msg      = "We have successfully authenticated you." .
        "\nYour login-id is: $resp->{loginid}" .
        "\nYour balance is: $resp->{balance}";
    my $keyboard = {
        "keyboard" => [["Trade", 'Logout'], ['Balance']],
        "one_time_keyboard" => \0
    };

    return {
        chat_id      => $chat_id,
        text         => $msg,
        reply_markup => $keyboard
    };
}

sub balance {
    my ($stash, $chat_id, $resp) = @_;
    my $val  = $resp->{balance};
    my $curr = $resp->{currency};
    my $msg  = "Balance: " . $curr . " $val.";

    return {
        chat_id => $chat_id,
        text    => $msg
    };
}
sub buy {
    my ($stash, $chat_id, $resp) = @_;
    my $currency    = get_property($chat_id, "currency");
    my $contract_id = $resp->{contract_id};
    my $buy_price   = $resp->{buy_price};
    my $balance     = $resp->{balance_after};
    my $msg         = "Succesfully bought contract at $currency $buy_price.\n" .
        "Your new balance: $currency $balance\n" .
        "Your contract-id: $contract_id";

    return {
        chat_id => $chat_id,
        text    => $msg
    };
}

sub error {
    my ($stash, $chat_id, $msg) = @_;

    return {
        chat_id => $chat_id,
        text    => "*Error:* $msg",
    };
}

sub logout {
    return {
        chat_id => $_[1],
        text    => 'You have been logged out.'
    };
}

sub proposal {
    my ($stash, $chat_id, $resp) = @_;
    my $currency = get_property($chat_id, "currency");
    my $id = $resp->{id};
    my $msg =
          "$resp->{longcode}"
        . "\nTotal cost: $resp->{ask_price}"
        . "\nPotential payout: $resp->{payout}"
        . "\n\nTo buy the contract please select the following option";
    my $keyboard = {
        inline_keyboard => [[{
                    text          => "Buy",
                    callback_data => "/buy $id $resp->{ask_price}"
                }]]};

    return {
        chat_id      => $chat_id,
        text         => $msg,
        reply_markup => $keyboard
    };
}

sub proposal_open_contract {
    my ($stash, $chat_id, $resp) = @_;
    # Return if the current spot is before entry tick.
    return if (!$resp->{entry_tick_time} || $resp->{current_spot_time} < $resp->{entry_tick_time});

    my $contract_id = $resp->{contract_id};
    my $count = ++$stash->{ticks_count}->{$contract_id};
    my $current_spot = $resp->{current_spot};
    $current_spot =~ s/(\d)$/*$1*/;
    my $msg = $resp->{current_spot_time} <= $resp->{date_expiry} ? "Tick #$count: ${current_spot}" : "";

    my $time = strftime("%Y-%m-%d %H:%M:%S", localtime($resp->{current_spot_time}));;
    $msg .= "    $time" if $msg;

    if ($resp->{is_sold}) {
        my $currency   = get_property($chat_id, "currency");
        my $buy_price  = $resp->{buy_price};
        my $sell_price = $resp->{sell_price};
        my $profit     = $sell_price - $buy_price;
        $msg .= "\n\nYou won $currency $profit." if $sell_price > 0;
        $msg .= "\n\nYou lost $currency $buy_price." if $sell_price == 0;
        delete $stash->{ticks_count}->{$contract_id};
        delete $stash->{$chat_id}->{processing_buy_req};
    }

    return {
        chat_id => $chat_id,
        text    => $msg
    };
}

sub escape_markdown {
    my $resp = shift;

    # return  is $resp is not defined.
    return unless defined($resp);

    if (ref($resp) eq "ARRAY") {
        my @arr = @$resp;
        foreach (@arr) {
            $_ = escape_markdown($_);
        }
        $resp = \@arr;
    } elsif (ref($resp) eq "HASH") {
        foreach (keys %$resp) {
            # Do not modify msg_type because it is used for calling relative subroutines
            $resp->{$_} = escape_markdown($resp->{$_}) unless $_ eq 'msg_type';
        }
    } else {
        $resp =~ s/([\*\_])/\\$1/g;
    }

    return $resp;
}

1;
