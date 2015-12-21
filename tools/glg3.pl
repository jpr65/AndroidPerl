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

$| = 1;

use vars qw($VERSION);
$VERSION ='0.120';

use v5.10;

use FileHandle;
use Data::Dumper;

# spartanic libs, stored in github
use lib '../spartanic/lib';
use Perl5::Spartanic;

use Scalar::Validation qw(:all);
# use PQL::Cache qw (:all);
# use Report::Porf qw(:all);

my $glg_lib = 'glg3';

require "$glg_lib/glg_a.pl";

# --- handle call args and configuration ----
# my $config_file = par configuration => -Default => './android.cfg.pl' => ExistingFile => shift;

# require $config_file;

my $aufg_name = par Aufgabe => -Optional => Filled => shift;
# my $aufg_name = "A1";
# my $aufg_name = "T1";

my %aufgaben;

sub add_aufgabe {
    my $name    = par AufgabenName => Filled  => shift;
    my $aufgabe = par Aufgabe      => HashRef => shift;

    $aufgabe->{-name} = $name;

    $aufgaben{$name} = $aufgabe;
}

# --- 3*3 Determinate berechnen ----
sub det3x3 {
    my @gl = map { [ @$_, @$_ ] } @_[0..2];

    my $det = 0;

    foreach my $j (0..2) {
        my $mul_positive = 1;
        my $mul_negative = 1;
        foreach my $i (0..2) {
            my $value = $gl[$i]->[$i+$j];
            $mul_positive *= $value;
            
            $value = $gl[$i]->[5-$i-$j];
            $mul_negative *= $value;
            # print "$value ";
        }
            # say " = $mul_positive";
        $det += $mul_positive;
        $det -= $mul_negative;
    }

   return $det; 
}

sub scalar_mul {
    my ($v1, $v2) = @_;

    my $result = 0;
    foreach my $i (0..$#$v1) {
        $result += $v1->[$i] * $v2->[$i];
    }

    return $result;
}

sub calc_aufgabe {
    my $aufgabe = shift;
    
    foreach my $gl_name (qw(A B C)) {
        my $gl = $aufgabe->{$gl_name};
        $gl->[3] = scalar_mul($aufgabe->{L}, $gl);
    }
    $aufgabe;
}

sub sprint_aufgabe {
    my $aufgabe   = shift;
   
    my $aufg_name = $aufgabe->{-name};
    
    my $result_str = "# === $aufg_name ===========\n\n";
    foreach my $gl_name (qw(A B C)) {
        my $gl = $aufgabe->{$gl_name};
        my $unbekannte  = 'x';
        my $result_line = '';
        foreach my $i (0..2) {
            my $faktor = $gl->[$i];
            $faktor = '- ' if $faktor eq '-1';
            $faktor = '+ ' if $faktor eq '+1';
            $result_line .= "$faktor$unbekannte ";
            $unbekannte++;
        }

        $result_line .= "= $gl->[3]\n";
        $result_line =~ s/^\+/ /o;
        $result_str .= $result_line; 
    }

    return $result_str;
}

sub validate_aufgabe {
    my $aufgabe = shift;

    my $det = det3x3(
         $aufgabe->{A},
         $aufgabe->{B},
         $aufgabe->{C},
        );

    die "Abhängige Gleichungen in Aufgabe $aufg_name !" unless $det;

    return $aufgabe;
}

sub sprint_loesung {
    my $aufgabe   = shift;
   
    my $aufg_name    = $aufgabe->{-name};
    my $loesung      = $aufgabe->{L};
    my $loesung_text = "# === $aufg_name === Loesung ========\n\n";
   
    my $unbekannte = 'x';
    foreach my $i (0..2) {
        my $wert = $loesung->[$i];
        $loesung_text .= "$unbekannte = $wert\n";
        $unbekannte++;
    }

    return $loesung_text;
}

my @aufgaben_liste;

if ($aufg_name) {
    push (@aufgaben_liste, $aufg_name); 
}
else {
    @aufgaben_liste = sort (keys (%aufgaben));
}


my $aufgabe_text;
my $loesung_text;

my $write_aufgabe = sub { say $aufgabe_text; };
my $write_loesung = sub { say $loesung_text; };
    
# --- alle Aufgaben ---  in Dateien speichern ---

unless ($aufg_name) {
    say "Write into files:";

    my ($aufgaben_file, $loesungs_file) = config_aufgaben();

    say $aufgaben_file;
    say $loesungs_file;
    
    my $aufgabe_fh = new FileHandle(">$aufgaben_file");
    my $loesung_fh = new FileHandle(">$loesungs_file");

    say $aufgabe_fh "# Aufgaben, generiert am " . localtime() ."\n";
    say $loesung_fh "# Loesungen, generiert am " . localtime() ."\n";

    $write_aufgabe = sub { say $aufgabe_fh $aufgabe_text; };
    $write_loesung = sub { say $loesung_fh $loesung_text; };
}

foreach $aufg_name (@aufgaben_liste) {

    my $aufgabe = validate_aufgabe($aufgaben{$aufg_name});
    $aufgabe    = calc_aufgabe    ($aufgabe);

    # print Dumper($aufgabe);
    $aufgabe_text = sprint_aufgabe($aufgabe);
    $write_aufgabe->(); 

    $loesung_text = sprint_loesung($aufgabe);
    $write_loesung->(); 

}

say qq();
say 'Done.';
