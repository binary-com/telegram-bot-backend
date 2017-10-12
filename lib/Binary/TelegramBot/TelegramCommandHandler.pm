package Binary::TelegramBot::TelegramCommandHandler;

use strict;
use warnings;

use Exporter qw(import);
use Binary::TelegramBot::SendMessage qw(send_message);
use Binary::TelegramBot::WSBridge qw(send_ws_request is_authenticated get_property);
use Binary::TelegramBot::WSResponseHandler qw(forward_ws_response);
use Binary::TelegramBot::Modules::Trade qw(process_trade subscribe_proposal);
use JSON qw(decode_json);

our @EXPORT = qw(process_message);

my $url = "https://4p00rv.github.io/BinaryTelegramBotLanding/index.html";
my $processed_buy_req = {};

my $commands = {
    "balance" => sub {
        my $chat_id  = shift;
        my $response = '';
        if (is_authenticated($chat_id)) {
            send_ws_response_on_ready($chat_id, {balance => 1});
        } else {
            send_un_authenticated_msg($chat_id);
            return;
        }
    },
    "buy" => sub {
        my ($chat_id, $arguments) = @_;
        my @args = split(/ /, $arguments, 2);
        my $response = 'Processing buy request.';

        # Return if buy request already processed
        return if $processed_buy_req->{$args[0]};

        $processed_buy_req->{$args[0]} = 1;

        send_message({
                chat_id => $chat_id,
                text    => $response
            });
        my $future = send_ws_request(
            $chat_id,
            {
                buy   => $args[0],
                price => $args[1]});
        $future->on_ready(
            sub {
                my $response    = $future->get;
                my $reply       = forward_ws_response($chat_id, $response);
                my $on_msg_sent = send_message($reply);
                $on_msg_sent->on_ready(
                    sub {
                        my $contract_id = decode_json($response)->{buy}->{contract_id};
                        subscribe_proposal($chat_id, $contract_id);
                    });
            });
    },
    'logout' => sub {
        my $chat_id = shift;
        send_ws_response_on_ready($chat_id, {logout => 1}) if is_authenticated($chat_id);
    },
    'null' => sub {
        #do nothing
    },
    'start' => sub {
        my ($chat_id, $token) = @_;
        my $response = $token ? 
        "Hi there! Welcome to [Binary.com\'s](https://www.binary.com) bot."
        . "\nWe\'re glad to see you here."
        . "\n\nPlease wait while we authorize you." : 
        "Please provide token in the request. eg: `/start <token>`";
        send_message({
                chat_id => $chat_id,
                text    => $response
            });
        send_ws_response_on_ready($chat_id, {authorize => $token}) if $token;
    },
    "trade" => sub {
        my ($chat_id, $arguments, $msgid) = @_;
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
                send_ws_response_on_ready($chat_id, $$ret[1]);
            }
        }
    },
    'undef' => sub {
        my $chat_id  = shift;
        my $response = 'A reply to that query is still being designed. Please hold on tight while this BOT evolves.';
        send_message({
                chat_id => $chat_id,
                text    => $response
            });
    }
};

sub process_message {
    my ($chat_id, $msg, $msgid) = @_;
    return if !$msg;
    if ($msg =~ m/^\/?([A-Za-z]+)\s?(.+)?/) {
        my $command   = lc($1);
        my $arguments = $2;
        $commands->{$command} ? $commands->{$command}->($chat_id, $arguments, $msgid) : $commands->{'undef'}->($chat_id);
        return;
    }
    $commands->{'undef'}->($chat_id);
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
    my ($chat_id, $request) = @_;
    my $future = send_ws_request($chat_id, $request);
    on_ready($chat_id, $future);
}

sub on_ready {
    my ($chat_id, $future) = @_;
    $future->on_ready(
        sub {
            my $response = $future->get;
            my $reply = forward_ws_response($chat_id, $response);
            send_message($reply);
        });
}

1;
