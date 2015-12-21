#==============================================================================
#
# glg_a.pl
#
#     Aufgaben für Lineare Gleichungssysteme mit 3 Unbekannten.
#
# Ralf Peine, Dec 2015
#
#==============================================================================

use strict;
use warnings;

use vars qw($VERSION);
$VERSION ='0.120';

use v5.10;

sub config_aufgaben {
    return map { "glg3/$_" } ('A_Aufgaben.txt', 'A_Loesungen.txt');
}

add_aufgabe(T1 =>
        {   
            L => [qw( +1  +2  +3 )],
            #          X   Y   Z
            A => [qw( +3  +2  -2 )],
            B => [qw( -2  +2  -3 )],
            C => [qw( +1  +4  -2 )],
        }
        );

add_aufgabe(A1 =>
        {   
            L => [qw( +1  +2  +3 )],
            #          X   Y   Z
            A => [qw( +3  +2  -2 )],
            B => [qw( -2  +2  -3 )],
            C => [qw( -1  +1  +2 )],
        }
        );

add_aufgabe(A2 =>
        {   
            L => [qw( -3  -4  -1 )],
            #          X   Y   Z
            A => [qw( +2  +1  -2 )],
            B => [qw( +2  -1  -3 )],
            C => [qw( +1  +1  +2 )],
        }
        );

add_aufgabe(A3 =>
        {   
            L => [qw( +5  -2  +3 )],
            #          X   Y   Z
            A => [qw( +3  +2  -4 )],
            B => [qw( -1  -2  +2 )],
            C => [qw( -1  +1  +3 )],
        }
        );

add_aufgabe(A4 =>
        {   
            L => [qw( -1  +4  -2 )],
            #          X   Y   Z
            A => [qw( +3  -2  -4 )],
            B => [qw( +2  +2  +2 )],
            C => [qw( -1  +1  +3 )],
        }
        );

add_aufgabe(A5 =>
        {   
            L => [qw( -2  -3  +4 )],
            #          X   Y   Z
            A => [qw( +3  +2  +3 )],
            B => [qw( +2  -2  +1 )],
            C => [qw( -1  +1  +2 )],
        }
        );

