use strict;
use warnings;
use Test::More "no_plan";
use Binary::TelegramBot::KeyboardGenerator qw(keyboard_generator merge_keyboards);
use Data::Dumper;

my @keys = [
    ['Digit Matches', '/trade DIGITMATCH'],
    ['Digit Differs', '/trade DIGITDIFF'],
    ['Digit Over',    '/trade DIGITOVER'],
    ['Digit Under',   '/trade DIGITUNDER'],
    ['Digit Even',    '/trade DIGITEVEN'],
    ['Digit Odd',     '/trade DIGITODD']];
my $title        = 'Please select a trade type';
my $keys_per_row = 3;
my $keyboard1    = keyboard_generator($title, @keys, $keys_per_row);

is_deeply(
    $keyboard1,
    [[{
                text          => '~~~ Please select a trade type ~~~',
                callback_data => 'null'
            }
        ],
        [{
                text          => 'Digit Matches',
                callback_data => '/trade DIGITMATCH'
            },
            {
                text          => 'Digit Differs',
                callback_data => '/trade DIGITDIFF'
            },
            {
                text          => 'Digit Over',
                callback_data => '/trade DIGITOVER'
            },
        ],
        [{
                text          => 'Digit Under',
                callback_data => '/trade DIGITUNDER'
            },
            {
                text          => 'Digit Even',
                callback_data => '/trade DIGITEVEN'
            },
            {
                text          => 'Digit Odd',
                callback_data => '/trade DIGITODD'
            }]
    ],
    'check returned keyboard'
);

@keys         = [['Lorem', 'lorem'], ['Ipsum', 'ipsum'], ['Dolor', 'dolor']];
$title        = 'Some task';
$keys_per_row = 2;
my $keyboard2 = keyboard_generator($title, @keys, $keys_per_row);

is_deeply(
    $keyboard2,
    [[{
                text          => '~~~ Some task ~~~',
                callback_data => 'null'
            }
        ],
        [{
                text          => 'Lorem',
                callback_data => 'lorem'
            },
            {
                text          => 'Ipsum',
                callback_data => 'ipsum'
            }
        ],
        [{
                text          => 'Dolor',
                callback_data => 'dolor'
            }]
    ],
    'check returned keyboard'
);

my $merged_keyboard = merge_keyboards($keyboard1, $keyboard2);
is_deeply(
    $merged_keyboard,
    [[{
                text          => '~~~ Please select a trade type ~~~',
                callback_data => 'null'
            }
        ],
        [{
                text          => 'Digit Matches',
                callback_data => '/trade DIGITMATCH'
            },
            {
                text          => 'Digit Differs',
                callback_data => '/trade DIGITDIFF'
            },
            {
                text          => 'Digit Over',
                callback_data => '/trade DIGITOVER'
            },
        ],
        [{
                text          => 'Digit Under',
                callback_data => '/trade DIGITUNDER'
            },
            {
                text          => 'Digit Even',
                callback_data => '/trade DIGITEVEN'
            },
            {
                text          => 'Digit Odd',
                callback_data => '/trade DIGITODD'
            }
        ],
        [{
                text          => '~~~ Some task ~~~',
                callback_data => 'null'
            }
        ],
        [{
                text          => 'Lorem',
                callback_data => 'lorem'
            },
            {
                text          => 'Ipsum',
                callback_data => 'ipsum'
            }
        ],
        [{
                text          => 'Dolor',
                callback_data => 'dolor'
            }]
    ],
    'merge keyboards'
);

# Check if selected key is highlighted
@keys         = [['Lorem', 'lorem'], ['Ipsum', 'ipsum'], ['Dolor', 'dolor']];
my $keyboard = keyboard_generator("Abcd", @keys, 2, 'Lorem');
is($keyboard->[1]->[0]->{text}, "\x{2705} Lorem", 'check if selected value is highlighted')

