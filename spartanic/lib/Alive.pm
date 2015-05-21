#==============================================================================
#
#  Alive Ticker
#
#  to show perl is still alive and working for long runnings
#  prints out chars every n-th call 
#
# Ralf Peine, Thu May 21 08:10:35 2015
#
#==============================================================================

package Alive;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION ='0.010';

use Perl5::Spartanic;

use Scalar::Validation qw(:all);

# --- ---------------------------------------------------
sub create {
    my $trouble_level = p_start;
    # my $self          = par self => $is_self => shift;
    my %pars          = convert_to_named_params \@_;
    
    my $smaller      = npar -smaller      => -Default => 10   => Int => \%pars;
    my $bigger       = npar -bigger       => -Default => 100  => Int => \%pars;
    my $newline      = npar -newline      => -Default => 1000 => Int => \%pars;
    my $smaller_char = npar -smaller_char => -Default => '.' => Scalar => \%pars;
    my $bigger_char  = npar -bigger_char  => -Default => ',' => Scalar => \%pars;
    my $name         = npar -name         => -Default => ''  => Scalar => \%pars;
        
    p_end \%pars;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------
 
    my $count = 0;
    
    $name .= ' ' if $name =~ /\S$/;   
    
    return sub {
        $count++;
        unless ($count % $newline) {
            print "\n$name$count ";
            return;
        }
        
        unless ($count % $bigger) {
            print $bigger_char;
            return;
        }
        
        unless ($count % $smaller) {
            print $smaller_char;
            return;
        }
    }    
}

1;