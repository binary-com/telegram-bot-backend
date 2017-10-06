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

my $commands = {
    'start' => sub {
        my ($chat_id, $token) = @_;
        my $response =
              "Hi there! Welcome to [Binary.com\'s](https://www.binary.com) bot."
            . "\nWe\'re glad to see you here."
            . "\n\nPlease wait while we authorize you.";
        send_message({
            chat_id => $chat_id,
            text    => $response
        });
        send_response_on_ready($chat_id, {authorize => $token});
    },
    'undef' => sub {
        my $chat_id  = shift;
        my $response = 'A reply to that query is still being designed. Please hold on tight while this BOT evolves.';
        send_message({
            chat_id => $chat_id,
            text    => $response
        });
    },
    'null' => sub {
        #do nothing
    },
    "balance" => sub {
        my $chat_id  = shift;
        my $response = '';
        if (is_authenticated($chat_id)) {
            send_response_on_ready($chat_id, {balance => 1});
        } else {
            send_un_authenticated_msg($chat_id);
            return;
        }
    },
    "trade" => sub {
        my ($chat_id, $arguments, $msgid) = @_;
        my $response = '';
        my $currency = get_property($chat_id, "currency");
        if (!is_authenticated($chat_id)) {
            send_un_authenticated_msg($chat_id);
            return;
        } else {
            my $ret = process_trade($arguments, $currency);
            if($ret->{proposal}) {
              send_response_on_ready($response);
            } else {
                $ret->{chat_id} = $chat_id;
                $ret->{message_id} = $message_id if $message_id;
                send_message($ret);
            }
        }
    },
    "buy" => sub {
        my ($chat_id, $arguments) = @_;
        my @args = split(/ /, $arguments, 2);
        my $response = 'Processing buy request.';
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

sub send_response_on_ready {
    my ($chat_id, $request) = @_;
    my $future = send_ws_request($chat_id, $request);
    $future->on_ready(
        sub {
            my $response = $future->get;
            my $reply = forward_ws_response($chat_id, $response);
            send_message($reply);
        });
}

1;
