package Binary::TelegramBot::TelegramCommandHandler;

use strict;
use warnings;

use Exporter qw(import);
use Binary::TelegramBot::SendMessage qw(send_message);
use Binary::TelegramBot::WSBridge qw(send_ws_request is_authenticated get_property);
use Binary::TelegramBot::WSResponseHandler qw(forward_ws_response);
use Binary::TelegramBot::Modules::Trade qw(process_trade);
use JSON qw(decode_json);

our @EXPORT = qw(process_message);

my $url = "https://4p00rv.github.io/BinaryTelegramBotLanding/index.html";

sub process_message {
    my ($stash, $chat_id, $msg, $msgid) = @_;
    my $commands = {
        "balance" => \&balance,
        "buy" => \&buy,
        'logout' => \&logout,
        'null' => \&do_nothing,
        'start' => \&start_cmd,
        "trade" => \&trade,
        'undef' => \&undefined_query
    };

    return if !$msg;
    if ($msg =~ m/^\/?([A-Za-z]+)\s?(.+)?/) {
        my $command   = lc($1);
        my $arguments = $2;
        $commands->{$command} ? $commands->{$command}->($stash, $chat_id, $arguments, $msgid) : $commands->{'undef'}->($chat_id);
        return;
    }
    $commands->{'undef'}->($chat_id);
}

sub balance {
    my ($stash, $chat_id)  = @_;
    my $response = '';
    if (is_authenticated($chat_id)) {
        send_ws_response_on_ready($stash, $chat_id, {balance => 1});
    } else {
        send_un_authenticated_msg($chat_id);
    }
}

sub buy {
    my ($stash, $chat_id, $arguments) = @_;
    my @args = split(/ /, $arguments, 2);
    my $response = 'Processing buy request.';

    # Return if buy request already processed
    return if $stash->{processed_buy_req}->{$args[0]}
        || $stash->{$chat_id}->{processing_buy_req};

    $stash->{processed_buy_req}->{$args[0]} = 1;
    $stash->{$chat_id}->{processing_buy_req} = 1;

    send_message({
            chat_id => $chat_id,
            text    => $response
        });
    my $future = send_ws_request(
        $stash, $chat_id,
        {
            buy   => $args[0],
            price => $args[1]});
    $future->on_ready(
        sub {
            my $response    = $future->get;
            my $reply       = forward_ws_response($stash, $chat_id, $response);
            my $on_msg_sent = send_message($reply);
            $on_msg_sent->on_ready(
                sub {
                    my $contract_id = decode_json($response)->{buy}->{contract_id};
                    subscribe_proposal($stash, $chat_id, $contract_id);
                });
        });
}

sub logout {
    my ($stash, $chat_id) = @_;
    if (is_authenticated($chat_id)) {
        send_ws_response_on_ready($stash, $chat_id, {logout => 1});
    } else {
        send_un_authenticated_msg($chat_id);
    }
}

sub do_nothing {
    #do nothing
}

sub start_cmd {
    my ($stash, $chat_id, $token) = @_;
    my $response = $token ?
    "Hi there! Welcome to [Binary.com\'s](https://www.binary.com) bot."
    . "\nWe\'re glad to see you here."
    . "\n\nPlease wait while we authorize you." :
    "Please provide token in the request. eg: `/start <token>`";
    send_message({
            chat_id => $chat_id,
            text    => $response
        });
    send_ws_response_on_ready($stash, $chat_id, {authorize => $token}) if $token;
}

sub trade {
    my ($stash, $chat_id, $arguments, $msgid) = @_;
    my $currency = get_property($chat_id, "currency");
    if (!is_authenticated($chat_id)) {
        send_un_authenticated_msg($chat_id);
        return;
    } else {
        my $ret = process_trade($arguments, $currency);
        $$ret[0]->{chat_id} = $chat_id;
        $$ret[0]->{message_id} = $msgid if $msgid;
        send_message($$ret[0]);
        if(scalar @$ret == 2 && $$ret[1]->{proposal}) {
            send_ws_response_on_ready($stash, $chat_id, $$ret[1]);
        }
    }
}

sub undefined_query {
    my ($stash, $chat_id)  = shift;
    my $response = 'A reply to that query is still being designed. Please hold on tight while this BOT evolves.';
    send_message({
            chat_id => $chat_id,
            text    => $response
        });
}

sub subscribe_proposal {
    my ($stash, $chat_id, $contract_id) = @_;
    my $request = {
        proposal_open_contract => 1,
        contract_id            => $contract_id,
        subscribe              => 1
    };

    send_ws_request(
        $stash, $chat_id, $request,
        sub {
            my ($chat_id, $response) = @_;
            my $resp_obj = decode_json($response);
            my $reply = forward_ws_response($stash, $chat_id, $response);
            send_message($reply);
        });
}

sub send_un_authenticated_msg {
    my $chat_id  = shift;
    my $response = "You need to authenticate first. \nVisit $url to authorize the bot.";
    send_message({
        chat_id => $chat_id,
        text    => $response
    });
}

sub send_ws_response_on_ready {
    my ($stash, $chat_id, $request) = @_;
    my $future = send_ws_request($stash, $chat_id, $request);
    on_ready($stash, $chat_id, $future);
}

sub on_ready {
    my ($stash, $chat_id, $future) = @_;
    $future->on_ready(
        sub {
            my $response = $future->get;
            my $reply = forward_ws_response($stash, $chat_id, $response);
            send_message($reply);
        });
}

1;
