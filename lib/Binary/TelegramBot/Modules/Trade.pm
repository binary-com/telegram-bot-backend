package Binary::TelegramBot::Modules::Trade;

use Binary::TelegramBot::WSBridge qw(send_ws_request);
use Binary::TelegramBot::SendMessage qw(send_message);
use Binary::TelegramBot::Helper::Await qw (await_response);
use Binary::TelegramBot::WSResponseHandler qw(forward_ws_response);
use Future;
use JSON qw(decode_json);
use Exporter qw(import);
use Binary::TelegramBot::KeyboardGenerator qw (keyboard_generator merge_keyboards);

our @EXPORT = qw(process_trade subscribe_proposal get_trade_type);

sub process_trade {
    my ($arguments, $currency) = @_;
    my @args = split(/ /, $arguments, 4);

    my $response_map = {
        0 => sub {
            my $args       = shift;
            my $trade_type = get_trade_type($$args[0]);
            my $underlying = $$args[1];
            my $payout     = $$args[2];
            my $duration   = $$args[3];
            return keyboard_generator(
                'Please select a trade type',
                [
                    ['Digit Matches', "/trade DIGITMATCH_$$trade_type[1] $underlying $payout $duration"],
                    ['Digit Differs', "/trade DIGITDIFF_$$trade_type[1] $underlying $payout $duration"],
                    ['Digit Over',    "/trade DIGITOVER_$$trade_type[1] $underlying $payout $duration"],
                    ['Digit Under',   "/trade DIGITUNDER_$$trade_type[1] $underlying $payout $duration"],
                    ['Digit Even',    "/trade DIGITEVEN_$$trade_type[1] $underlying $payout $duration"],
                    ['Digit Odd',     "/trade DIGITODD_$$trade_type[1] $underlying $payout $duration"]
                ],
                3, $$trade_type[0]
            );
        },
        1 => sub {
            my $args = shift;
            my $trade_type = $$args[0];
            my $payout     = $$args[2];
            my $duration   = $$args[3];
            #Check if contract requires barrier.
            my $barrier_keys = ask_for_barrier($args);
            my $keys = keyboard_generator(
                'Please select an underlying',
                [
                    ['Volatility Index 10',  "/trade $trade_type R_10 $payout $duration"],
                    ['Volatility Index 25',  "/trade $trade_type R_25 $payout $duration"],
                    ['Volatility Index 50',  "/trade $trade_type R_50 $payout $duration"],
                    ['Volatility Index 75',  "/trade $trade_type R_75 $payout $duration"],
                    ['Volatility Index 100', "/trade $trade_type R_100 $payout $duration"]
                ],
                2, get_underlying_name($args[1])
            );

            if($barrier_keys) {
                return merge_keyboards($barrier_keys, $keys);
            }
            return $keys;
        },
        2 => sub {
            my $args       = shift;
            my $currency   = shift;
            my $trade_type = $$args[0];
            my $underlying = $$args[1];
            my $duration   = $$args[3];

            return keyboard_generator(
                'Please select a payout',
                [
                    ["5 $currency",   "/trade $trade_type $underlying 5 $duration"],
                    ["10 $currency",  "/trade $trade_type $underlying 10 $duration"],
                    ["25 $currency", "/trade $trade_type $underlying 25 $duration"],
                    ["50 $currency",  "/trade $trade_type $underlying 50 $duration"],
                    ["100 $currency", "/trade $trade_type $underlying 100 $duration"]
                ],
                3, "$$args[2] $currency"
            );
        },
        3 => sub {
            my $args = shift;
            my $trade_type = $$args[0];
            my $underlying = $$args[1];
            my $payout     = $$args[2];
            return keyboard_generator(
                'Please select a duration',
                [
                    ['5 ticks',  "/trade $trade_type $underlying $payout 5"],
                    ['6 ticks',  "/trade $trade_type $underlying $payout 6"],
                    ['7 ticks',  "/trade $trade_type $underlying $payout 7"],
                    ['8 ticks',  "/trade $trade_type $underlying $payout 8"],
                    ['9 ticks',  "/trade $trade_type $underlying $payout 9"],
                    ['10 ticks', "/trade $trade_type $underlying $payout 10"]
                ],
                3, "$$args[3] ticks"
            );
        },
        4 => sub {
            my ($trade_type, $barrier) = split(/_/, $args[0], 2);
            my $underlying = $args[1];
            my $payout     = $args[2];
            my $duration   = $args[3];
            # send_proposal(
            #     $chat_id,
            #     {
            #         underlying    => $underlying,
            #         payout        => $payout,
            #         contract_type => $trade_type,
            #         duration      => $duration,
            #         barrier       => $barrier
            #     });
        }
    };

    my $keyboard = [];
    my $arg_length = 0;

    for( my $i = 0; $i < 4; $i++) {
        if($args[$i]) {
          $arg_length++;
        }
        my $keys = $response_map->{$i}(\@args, $currency);
        $keyboard = merge_keyboards($keyboard, $keys);
    }


    if($arg_length == 4) {
      # All the required options were selected by user. Sending a proposal request.
    }

    return {
            text         => 'Please select options',
            reply_markup => {inline_keyboard => $keyboard}};
}

sub ask_for_barrier {
    my $args = shift;
    my $underlying = $$args[1];
    my $payout     = $$args[2];
    my $duration   = $$args[3];
    my ($trade_type, $barrier) = split(/_/, $$args[0], 2);;
    my @requires_barrrier = qw(DIGITMATCH DIGITDIFF DIGITUNDER DIGITOVER);
    if (grep(/^$trade_type$/, @requires_barrrier)) {
        my $arr_keys = [
            ['1', "/trade ${trade_type}_1 $underlying $payout $duration"],
            ['2', "/trade ${trade_type}_2 $underlying $payout $duration"],
            ['3', "/trade ${trade_type}_3 $underlying $payout $duration"],
            ['4', "/trade ${trade_type}_4 $underlying $payout $duration"],
            ['5', "/trade ${trade_type}_5 $underlying $payout $duration"],
            ['6', "/trade ${trade_type}_6 $underlying $payout $duration"],
            ['7', "/trade ${trade_type}_7 $underlying $payout $duration"],
            ['8', "/trade ${trade_type}_8 $underlying $payout $duration"]];
        unshift @$arr_keys, ['0', "/trade ${trade_type}_0   "] if ($trade_type ne 'DIGITUNDER');
        push @$arr_keys,    ['9', "/trade ${trade_type}_9   "] if ($trade_type ne 'DIGITOVER');
        my $keys = keyboard_generator('Please select a digit', $arr_keys, 5, $barrier);
        return $keys;
    }
    return undef;
}

sub send_proposal {
    my ($params, $currency) = @_;
    my $request = {
        proposal      => 1,
        amount        => $params->{payout},
        basis         => 'payout',
        contract_type => $params->{contract_type},
        currency      => $currency,
        duration      => $params->{duration},
        duration_unit => 't',
        symbol        => $params->{underlying}};
    $request->{barrier} = $params->{barrier} if $params->{barrier} ne '';
    # my $future = send_ws_request($chat_id, $request);
    # $future->on_ready(
    #     sub {
    #         my $response = $future->get;
    #         my $reply = forward_ws_response($chat_id, $response);
    #         send_message($reply);
    #     });
    return;
}

sub subscribe_proposal {
    my ($chat_id, $contract_id) = @_;
    my $request = {
        proposal_open_contract => 1,
        contract_id            => $contract_id,
        subscribe              => 1
    };

    send_ws_request(
        $chat_id, $request,
        sub {
            my ($chat_id, $response) = @_;
            my $resp_obj = decode_json($response);
            my $reply = forward_ws_response($chat_id, $response);
            send_message($reply);
        });
}

sub get_trade_type {
    my $arguments = shift;
    my @args      = split(/_/, $arguments, 2);
    my $name      = {
        "DIGITMATCH" => "Digit Matches",
        "DIGITDIFF"  => "Digit Differs",
        "DIGITOVER"  => "Digit Over",
        "DIGITUNDER" => "Digit Under",
        "DIGITEVEN"  => "Digit Even",
        "DIGITODD"   => "Digit Odd"
    }->{$args[0]};
    return [$name, $args[1]];
}

sub get_underlying_name {
    my $symbol = shift;
    return {
        R_10  => "Volatility Index 10",
        R_25  => "Volatility Index 25",
        R_50  => "Volatility Index 50",
        R_75  => "Volatility Index 75",
        R_100 => "Volatility Index 100"
    }->{$symbol};
}

1;
