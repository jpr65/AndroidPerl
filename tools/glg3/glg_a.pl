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

add_aufgabe(A001 =>
        {   
            L => [qw( +1  +2  +3 )],
            #          X   Y   Z
            A => [qw( +3  +2  -2 )],
            B => [qw( -2  +2  -3 )],
            C => [qw( -1  +1  +2 )],
        }
        );

add_aufgabe(A002 =>
        {   
            L => [qw( -3  -4  -1 )],
            #          X   Y   Z
            A => [qw( +2  +1  -2 )],
            B => [qw( +2  -1  -3 )],
            C => [qw( +1  +1  +2 )],
        }
        );

add_aufgabe(A003 =>
        {   
            L => [qw( +5  -2  +3 )],
            #          X   Y   Z
            A => [qw( +3  +2  -4 )],
            B => [qw( -1  -2  +2 )],
            C => [qw( -1  +1  +3 )],
        }
        );

add_aufgabe(A004 =>
        {   
            L => [qw( -1  +4  -2 )],
            #          X   Y   Z
            A => [qw( +3  -2  -4 )],
            B => [qw( +2  +2  +2 )],
            C => [qw( -1  +1  +3 )],
        }
        );

add_aufgabe(A005 =>
        {   
            L => [qw( -2  -3  +4 )],
            #          X   Y   Z
            A => [qw( +3  +2  +3 )],
            B => [qw( +2  -2  +1 )],
            C => [qw( -1  +1  +2 )],
        }
        );

add_aufgabe(A007 =>
        {   
            L => [qw( +1  -2  -2 )],
            #          X   Y   Z
            A => [qw( +3  -2  +2 )],
            B => [qw( -1  +3  +1 )],
            C => [qw( -1  -3  +2 )],
        }
        );

add_aufgabe(A008 =>
        {   
            L => [qw( -3  +1  +2 )],
            #          X   Y   Z
            A => [qw( -3  -2  -2 )],
            B => [qw( -1  +3  +1 )],
            C => [qw( +1  +3  -2 )],
        }
        );

add_aufgabe(A009 =>
        {   
            L => [qw( +4  -1  -3 )],
            #          X   Y   Z
            A => [qw( -2  -4  -2 )],
            B => [qw( -1  +3  -1 )],
            C => [qw( +1  +3  +2 )],
        }
        );

add_aufgabe(A010 =>
        {   
            L => [qw( -6  +7  -2 )],
            #          X   Y   Z
            A => [qw( -4  -3  -2 )],
            B => [qw( +2  +2  -1 )],
            C => [qw( +3  +1  -6 )],
        }
        );

add_aufgabe(A011 =>
        {   
            L => [qw( +4  -1  -3 )],
            #          X   Y   Z
            A => [qw( -2  -4  -2 )],
            B => [qw( -1  +3  -1 )],
            C => [qw( +1  +3  +2 )],
        }
        );

add_aufgabe(A012 =>
        {   
            L => [qw( +7  -8  -9 )],
            #          X   Y   Z
            A => [qw( -2  -4  +2 )],
            B => [qw( -1  +3  -4 )],
            C => [qw( +1  +3  -1 )],
        }
        );

add_aufgabe(A013 =>
        {   
            L => [qw( -5  -3  +2 )],
            #          X   Y   Z
            A => [qw( +1  -2  +2 )],
            B => [qw( -2  +2  -4 )],
            C => [qw( +3  -7  -1 )],
        }
        );

add_aufgabe(A014 =>
        {   
            L => [qw( -4  -4  +4 )],
            #          X   Y   Z
            A => [qw( -2  +4  +2 )],
            B => [qw( -1  +3  +4 )],
            C => [qw( +1  +3  +2 )],
        }
        );

add_aufgabe(A015 =>
        {   
            L => [qw( -5  -7  +6 )],
            #          X   Y   Z
            A => [qw( -2  +4  +2 )],
            B => [qw( -1  -3  -4 )],
            C => [qw( -7  +4  -2 )],
        }
        );

add_aufgabe(A016 =>
        {   
            L => [qw( -3  +8  +5 )],
            #          X   Y   Z
            A => [qw( +3  +2  -2 )],
            B => [qw( -1  -3  +5 )],
            C => [qw( +7  +3  -2 )],
        }
        );

add_aufgabe(A017 =>
        {   
            L => [qw( +7  -2  +4 )],
            #          X   Y   Z
            A => [qw( -2  +4  +4 )],
            B => [qw( -1  -3  +1 )],
            C => [qw( -4  -7  +2 )],
        }
        );

add_aufgabe(A018 =>
        {   
            L => [qw( +6  -2  -3 )],
            #          X   Y   Z
            A => [qw( -2  -7  +3 )],
            B => [qw( -1  -3  -3 )],
            C => [qw( -7  -9  -7 )],
        }
        );

