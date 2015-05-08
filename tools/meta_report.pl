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

our %special_dirs;

# --- handle call args and configuration ----
my $config_file = par configuration => -Default => './android.cfg.pl' => ExistingFile => shift;

require $config_file;

my $config = MyConfig::get();

our $perl_meta_db_file = npar -perl_meta_db_file => ExistingFile => $config;
our $html_output_path  = npar -html_out_path     => ExistingDir  => $config;

our $startup_file      = "$html_output_path/_index.html";

# --- load database ------

our $perl_meta_info_db;
our $meta_perl_info_service = new Perl5::MetaInfo::DB();

$meta_perl_info_service->read($perl_meta_db_file);

# ----------

# s/^'//o;

say "# select classes ...";

my $class_info_list     = $meta_perl_info_service->select_complete_class_infos();
my $namespace_info_list = $meta_perl_info_service->select_complete_namespace_infos();

# say Dumper $class_info_list->[0];
sub create_path_for_file {
    my $trouble_level  = p_start;

    my $file_with_path = par file_with_path => Filled => shift;
    
    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------
    
    my $path = dirname($file_with_path);
    make_path($path) unless -d $path;
    
    return $file_with_path;
}

# --- combine given paths and add ../ if not starting at root dir -------------
sub combine_html_paths {
    my $path  = '';
    my $slash = '';
    
    while (scalar @_) {
	       my $path_part = par path_part
	                       => -Default => '?'
	                       => Scalar   => shift
	       ;
	       $path .= $slash.$path_part;
	       $slash = "/";
    }

    my $drive = '';

    # windows path like E:bla
    if ($path =~ m{(^[A-Za-z]:)(.*)}) {
	       $drive = $1;
	       $path  = $2;
    }
    
    if ($path !~ m{^/} ) {
        $path = "../$path";
    }
    
    my $result_path = "$drive$path"; 

    # say $result_path;

    return $result_path;
}

sub prepare_html_filenames {
    my $trouble_level     = p_start;
    
    my $name_property  = par name_property  => Filled   => shift;
    my $meta_info_list = par meta_info_list => ArrayRef => shift;
    
    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------

    foreach my $meta_info (@$meta_info_list) {
        my $fullname = $meta_info->{$name_property};
        my $module_source = 'modules';
        
        # say $fullname;
        
        if ($meta_info->{filename} =~ /^{(\w+)}/) {
            $module_source = $1;
        } 
        
        $special_dirs{$module_source}++;
        
        my $html_file = "$html_output_path/$module_source/$fullname.html";
        $html_file =~ s{::}{/}og;
        create_path_for_file($html_file);
        # say $html_file;
    
        $meta_info->{_html_file} = $html_file;
    }
}

sub prepare_namespace_html_filenames {
    my $trouble_level     = p_start;
    
    my $namespace_info_list = par namespace_info_list => ArrayRef => shift;
    
    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------
    
    foreach my $namespace_info (@$namespace_info_list) {
        $namespace_info->{_index_html_filename} = $namespace_info->{name}."::_index";
    }
    prepare_html_filenames(_index_html_filename => $namespace_info_list);
}

sub create_class_overview_report {
    my $trouble_level     = p_start;
    
    my $current_namespace = par current_namespace => Scalar => shift;
    
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
    $report->cc(-h => 'Namespace', -w => 30, -esc => 0,
                -v  => sub { build_namespace_links_down($current_namespace, $_[0]->{'namespace'}); 
                           }
    );
    $report->cc(-h => '#Line',     -w =>  5,  -v  => '$_[0]->{line_nbr} || 0',
                                   -a => 'r', -f  => "%5d");
    $report->cc(-h => 'File',      -w => 45,  -vn => 'filename');
    
    $report->configure_complete();
    
    return $report;
}

sub report_class_overview_list {
    my $trouble_level     = p_start;
    
    my $class_info_list = par class_info_list => ArrayRef => shift;
    
    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------
    
    my $report = create_class_overview_report();
    my $report_file = create_path_for_file("$html_output_path/modules/_index.html");
    
    my $report_file_handle = new FileHandle;
    $report_file_handle->open(">$report_file");

    say $report_file_handle '<html>';
    say $report_file_handle '<title>Perl Class Overview</title>';
    say $report_file_handle '<body>';
    
    say $report_file_handle '<h1>Perl Module/Class Overview</h1>';
    
    say $report_file_handle '<h4>Generated: '.localtime().'</h4>';
    say $report_file_handle '<h4>Modules listed: '.scalar(@$class_info_list).'</h4>';
    
    print $report_file_handle $report->get_table_start();
    
    print $report_file_handle $report->get_header_output();
       
    $report->write_table($class_info_list, $report_file_handle);
    
    say $report_file_handle $report->get_table_end();

    say $report_file_handle '</body>';
    say $report_file_handle '</html>';
}

sub build_home_link {
    my $trouble_level     = p_start;
    
    my $namespace = par namespace => Scalar => shift;
    
    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------
    
    my @namespace_splitted = split (/::?/, $namespace);
    
    my $dir_level = scalar (@namespace_splitted);
    my $top_path  = "../" x $dir_level;
    
    # say "$dir_level $top_path $namespace";
    
    return "<a href='${top_path}_index.html'>Home</a>";
}

sub build_namespace_links_up {
    my $trouble_level     = p_start;
    
    my $namespace = par namespace => Scalar => shift;
    
    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------
    
    return "" unless $namespace;
    
    my $namespace_html = "";
    
    my $dir_up = '.';
    foreach my $part (reverse (split (/::?/, $namespace))) {
        $namespace_html = "<a href='$dir_up/_index.html'>$part</a>::$namespace_html";
        $dir_up .= '/..';
    }
    
    $namespace_html =~ s/::$//;
    
    # say $namespace_html;
    
    return $namespace_html;
}

sub build_namespace_links_down {
    my $trouble_level     = p_start;
    
    my $start_dir = par start_dir => Scalar => shift;
    my $namespace = par namespace => Scalar => shift;
    
    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------
    
    return "" unless $namespace;
    
    my @dirs_up = split (/::?/, $start_dir);
    # shift @dirs_up;
    my $dir_up = join('/', map { ".." } @dirs_up);
    $dir_up .= '/' if $dir_up;
    
    # say "dir_up $dir_up";
    
    my $namespace_html = "";
    
    my $dir_down = "";
    foreach my $part (split (/::?/, $namespace)) {
        $dir_down .= $part;
        $namespace_html .= "<a href='$dir_up$dir_down/_index.html'>$part</a>::";
        $dir_down .= '/';
    }
    
    $namespace_html =~ s/::$//;
    
    # say "namespace_html = $namespace_html";
    
    return $namespace_html;
}

sub report_class_methods {
    my $trouble_level     = p_start;
    
    my $class_info = par class_info => HashRef => shift;
    
    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------

    my $fullname        = $class_info->{fullname};
    my $classname       = $class_info->{classname};
    my $namespace       = $class_info->{namespace};
    my $module_filename = $class_info->{filename};
    my $html_file       = $class_info->{_html_file};
    
    my @method_list;
    foreach my $method_name (sort(keys %{$class_info->{subs}})) {
        my $method_info = $class_info->{subs}->{$method_name};
        # say "\t$method_info->{name}";
        
        push (@method_list, $method_info);
    }

    my $framework = Report::Porf::Framework::get();
    my $report    = $framework->create_report('html');
    
    $report->cc(-h => 'ID',    -w =>  5,  -vn => 'ID',   -a => 'r', -f  => "%5d");
    $report->cc(-h => '#Line', -w =>  5,  -v  => '$_[0]->{line_nbr} || 0',
                               -a => 'r', -f  => "%5d");
    $report->cc(-h => '***',     -w =>  1,  -v => 'return ""; ');
    $report->cc(-h => 'Name',  -w => 30,  -vn => 'name');
    
    $report->configure_complete();
    
    my $done = eval {
	       print "report $html_file ... ";
	       
	       my $report_file_handle = new FileHandle;

        $report_file_handle->open(">$html_file");

        say $report_file_handle '<html>';
        say $report_file_handle "<title>Perl Module/Class: $fullname</title>";
        say $report_file_handle '<body>';
    
        my $namespace_html = build_namespace_links_up($namespace);
        
        say $report_file_handle "<h1>$namespace_html::$classname</h1>";
        
        say $report_file_handle "<h3>".build_home_link($namespace)."</h3>";
        
        say $report_file_handle "<h4>$module_filename</h4>";
        say $report_file_handle '<h4>'.localtime().'</h4>';
        say $report_file_handle '<h4>Subs listed: '.scalar(@method_list).'</h4>';
    
        print $report_file_handle $report->get_table_start();
    
        print $report_file_handle $report->get_header_output();
       
        $report->write_table(\@method_list, $report_file_handle);
    
        say $report_file_handle $report->get_table_end();

        say $report_file_handle '</body>';
        say $report_file_handle '</html>';

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

sub report_namespace {
    my $trouble_level   = p_start;
    
    my $namespace       = par namespace       => Filled   => shift;
    
    p_end \@_;

    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------
    print "generate overview of namespace $namespace ... ";

    my $class_info_list = $meta_perl_info_service
        ->select_class_objects('^'.$namespace.'::\w+$');
 
    print "with ".scalar(@$class_info_list)." classes ... ";
    # say Dumper ($class_info_list);
    
    my $report         = create_class_overview_report($namespace);
    my $namespace_path = $namespace || '.';
    $namespace_path    =~ s{::}{/}og;
    foreach my $lib_dir (keys(%special_dirs)) {
        my $report_file    = create_path_for_file(
            "$html_output_path/$lib_dir/$namespace_path/_index.html"
        );
        
        # say $report_file;
        
        my $report_file_handle = new FileHandle;
        $report_file_handle->open(">$report_file");

        say $report_file_handle '<html>';
        say $report_file_handle "<title>Perl Namespace $namespace</title>";
        say $report_file_handle '<body>';
    
        my $namespace_html = build_namespace_links_up($namespace);
        
        say $report_file_handle "<h1>$namespace_html</h1>";
        
        say $report_file_handle "<h3>".build_home_link($namespace)."</h3>";
        
        say $report_file_handle "<h2>Modules Of Namespace</h1>";
    
        say $report_file_handle '<h4>Generated: '.localtime().'</h4>';
        say $report_file_handle '<h4>Modules listed: '.scalar(@$class_info_list).'</h4>';
    
        print $report_file_handle $report->get_table_start();
    
        print $report_file_handle $report->get_header_output();
       
        $report->write_table($class_info_list, $report_file_handle);
    
        say $report_file_handle $report->get_table_end();

        say $report_file_handle '</body>';
        say $report_file_handle '</html>';
    }
    say "Done";
	   1;
}

prepare_html_filenames(fullname => $class_info_list);

say "namespace filenames";
# print Dumper($namespace_info_list);

prepare_namespace_html_filenames($namespace_info_list);

# print Dumper($namespace_info_list);

# die "STOP";

report_class_overview_list($class_info_list);

foreach my $class_info (@$class_info_list) {
    report_class_methods($class_info);
}

my @namespace_keys = map { 
    $_->{name};
} @$namespace_info_list;

foreach my $namespace (@namespace_keys) {
    next unless $namespace;    
    report_namespace($namespace);
}

say '*** All Done ***';
