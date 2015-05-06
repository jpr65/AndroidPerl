#==============================================================================
#
# meta_report.pl
#
#      Read dump of PQL::Cache created by meta_scan.pl and
#      create documentation.
#
# Ralf Peine, Mon May 03 08:33:17 2015
#
#==============================================================================

use strict;
use vars qw($VERSION);
$VERSION ='0.101';

$| = 1;
use v5.10;

use Data::Dumper;
use File::Basename;
use File::Path qw(make_path);

# spartanic libs, stored in github
use lib '../spartanic/lib';

use Perl5::Spartanic;

use Scalar::Validation qw(:all);
use PQL::Cache qw (:all);
use Report::Porf qw(:all);

use Perl5::MetaInfo::DB;

# --- handle call args and configuration ----
my $config_file = par configuration => -Default => './android.cfg.pl' => ExistingFile => shift;

require $config_file;

my $config = MyConfig::get();

our $perl_meta_db_file = npar -perl_meta_db_file => ExistingFile => $config;
our $html_output_path  = npar -html_out_path     => ExistingDir  => $config;

# --- load database ------

our $perl_meta_info_db;
our $meta_perl_info_service = new Perl5::MetaInfo::DB();

$meta_perl_info_service->read($perl_meta_db_file);

# ----------

# s/^'//o;

say "# select classes ...";

my $class_info_list = $meta_perl_info_service->select_complete_class_infos();

# say Dumper $class_info_list->[0];

# --- combine given paths and add ../ if not starting at root dir -------------
sub combine_html_paths {
    my $path  = '';
    my $slash = '';
    
    while (scalar @_) {
	my $path_part = par path_part => Filled => shift;
	$path .= $slash.$path_part;
	$slash = "/";
    }

    my $drive = '';

    # windows path like E:bla
    if ($path =~ m{(^[A-Za-z]:)(.*)}) {
	$drive = $1;
	$path  = $2;
    }
    
    if ($path =~ m{^/} ) {
    }
    else {
	$path = "../$path";
    }

    return "$drive$path";
}

sub report_classes {
    my $trouble_level     = p_start;
    
    my $class_info_list = par class_info_list => ArrayRef => shift;
    
    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------
    
    my $framework = Report::Porf::Framework::get();
    my $report    = $framework->create_report('html');
    
    $report->cc(-h => 'ID',        -w =>  5,  -vn => 'ID',
                                   -a => 'r', -f  => "%5d");
    $report->cc(-h => 'Name',      -w => 30,  -a  =>'c', -esc => 0,
                -v => sub { '<a href="' . combine_html_paths($_[0]->{_html_file}) .'">'
                                        . $_[0]->{classname}  . '</a>'; 
                          }
               );
    $report->cc(-h => 'Namespace', -w => 30,  -vn => 'namespace');
    $report->cc(-h => '#Line',     -w =>  5,  -v  => '$_[0]->{line_nbr} || 0',
                                   -a => 'r', -f  => "%5d");
    $report->cc(-h => 'File',      -w => 45,  -vn => 'filename');
    
    $report->configure_complete();
    
    my $report_file = create_path_for_file("$html_output_path/modules/index.html");
       
    $report->write_all($class_info_list, $report_file);
}

sub create_path_for_file {
    my $trouble_level     = p_start;
    
    my $file_with_path = par file_with_path => Filled => shift;
    
    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------
    
    my $path = dirname($file_with_path);
    make_path($path) unless -d $path;
    
    return $file_with_path;
}

sub prepare_html_filenames {
    my $trouble_level     = p_start;
    
    my $file_with_path = par file_with_path => ArrayRef => shift;
    
    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------

    foreach my $class_info (@$class_info_list) {
        my $fullname = $class_info->{fullname};
        my $module_source = 'modules';
        if ($class_info->{filename} =~ /^{(\w+)}/) {
            $module_source = $1;
        } 
        my $html_file = "$html_output_path/$module_source/$fullname.html";
        $html_file =~ s{::}{/}og;

	my $done = eval {
	    create_path_for_file($html_file);
	    say $html_file;
	    1;
	};

	unless ($done) {
	    warn "could not crate path for file $html_file: $!";
	}
    
        $class_info->{_html_file} = $html_file;
    }
}

prepare_html_filenames($class_info_list);
report_classes($class_info_list);

foreach my $class_info (@$class_info_list) {
    my $fullname = $class_info->{fullname};
    
    my $html_file = $class_info->{_html_file};
    
    my @method_list;
    foreach my $method_name (sort(keys %{$class_info->{subs}})) {
        my $method_info = $class_info->{subs}->{$method_name};
        # say "\t$method_info->{name}";
        
        push (@method_list, $method_info);
    }

    my $done = eval {
	print "report $html_file ... ";
	auto_report(\@method_list, $html_file);
	say "Done";
	1;
    };

    unless ($done) {
	my $error_message = $@;
	say "\n\tError: $error_message";
	my $html_fh = new FileHandle();
	$html_fh->open(">$html_file");
	say $html_fh "<html>";
	say $html_fh "<body>";
	say $html_fh "Could not create html method documentation, error was:";
	say $html_fh $error_message;
	say $html_fh "</body>";
	say $html_fh "</html>";
    }
}
