#==============================================================================
#
# meta_report.pl
#
#      Read dump of PQL::Cache created by meta_scan.pl and
#      create documentation.
#
# Ralf Peine, Wed May 27 08:06:22 2015
#
#==============================================================================

# s/^'//o;

use strict;
use warnings;

$| = 1;

use vars qw($VERSION);
$VERSION ='0.120';

use v5.10;

use Data::Dumper;
use File::Basename;
use File::Path qw(make_path remove_tree);
use File::stat;
use Pod::Html;

# spartanic libs, stored in github
use lib '../spartanic/lib';

use Perl5::Spartanic;

use Alive qw(:all);
use Log::Trace;

use Scalar::Validation qw(:all);
use PQL::Cache qw (:all);
use Report::Porf qw(:all);

use Perl5::MetaInfo::DB;

our %special_dirs;

# --- handle call args and configuration ----
my $config_file = par configuration => -Default => './android.cfg.pl' => ExistingFile => shift;

require $config_file;

my $config = MyConfig::get();

say "# start meta report ...";

our $perl_meta_db_file = npar -perl_meta_db_file => ExistingFile    => $config;
our $scan_paths        = npar -scan_paths        => HashRef         => $config;
our $html_output_path  = npar -html_out_path     => ExistingDir     => $config;
our $doc_path_hashref  = npar -doc_paths         => HashRef         => $config;

foreach my $doc_region (sort(keys(%$doc_path_hashref))) {
    unless (-d $doc_path_hashref->{$doc_region}) {
        my $not_existing_path = delete $doc_path_hashref->{$doc_region};
        say "# ignore not existing documentation path $not_existing_path";
    }
}

our $startup_file      = "$html_output_path/_index.html";

# --- setup trace ---
my $trace_mode  = npar -trace_mode => -Default => off
                     => -Enum => [qw(off print file)]
                     => $config;
                    
my $trace_level = npar -trace_level => -Default  => -1 => Int    => $config;
my $trace_file  = npar -trace_file  => -Optional =>    => Filled => $config;

my @trace_args;

if ($trace_mode ne 'off') {
    
    my %trace_opts;
    
    if ($trace_level >= 0) {
        $trace_opts{Level} = [$trace_level, undef];
        $trace_opts{Deep}  = 1;    
    }
    
    if ($trace_mode eq 'file') {
        $trace_file = par -trace_file  => Filled => $trace_file;
        @trace_args = ($trace_mode => $trace_file, \%trace_opts);
        say "# Trace into file $trace_file";
    }
    else {
        @trace_args = ($trace_mode => \%trace_opts);
    }
    
    import Log::Trace @trace_args;
    
    TRACE '# === Start at ' . localtime() . ' ========================';
}

if ($trace_mode eq 'print') {
    Alive::all_off();
}
else {
    Alive::setup(
        -factor => 10,
        -name   => '# ',
    );
}

# --- load database ------

our $perl_meta_info_db;
our $meta_perl_info_service = new Perl5::MetaInfo::DB();

$meta_perl_info_service->read($perl_meta_db_file);

TRACE "# select classes ...";

my $class_info_list     = $meta_perl_info_service->select_complete_class_infos();
my $namespace_info_list = $meta_perl_info_service->select_complete_namespace_infos();

# === subs =========================================

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
	       $drive = "file:///$1";
	       $path  = $2;
    }
    
    if ($path !~ m{^/} ) {
        $path = "../$path";
    }
    
    my $result_path = "$drive$path"; 

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
        
        if (defined $meta_info->{filename} && $meta_info->{filename} =~ /^{(\w+)}/) {
            $module_source = $1;
        } 
        
        $special_dirs{$module_source}++;

	        my $html_file = $html_output_path;
        $html_file .= "/$module_source/$fullname.html";
        $html_file =~ s{::}{/}og;

        create_path_for_file($html_file);
        
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

sub build_doc_filename {

    my $trouble_level = p_start;
    
    my $html_file = par full_class_name => Filled => shift;
    
    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------
    
    $html_file =~ s{::}{/}og;
    
    my $link ='';
    
    foreach my $doc_path_name (sort(keys(%$doc_path_hashref))) {
        my $doc_path       = $doc_path_hashref->{$doc_path_name};
        my $source_dir     = $scan_paths->{$doc_path_name};
        
        my $module_file    = "$source_dir/$html_file.pm";
        my $full_html_file = "$doc_path/$html_file.html";
        
        if (-f $module_file) {
            gen_doc_html(
                -source_dir  => $source_dir, 
                -html_dir    => $doc_path,
                -source_file => $module_file,
                -html_file   => $full_html_file,
            );
        }

        if (-f $full_html_file) {
            $link .= ', ' if $link;
            $link .= "<a href='$full_html_file'>$doc_path_name</a>";
        }
    }
    
    return prepare_url($link);
}

# add file:/// if 
sub prepare_url {
    my $trouble_level = p_start;
    
    my $url           = par url => Scalar => shift;
    
    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------
        
    $url = "file:///$url" if $url =~ /^\w:/;

    return $url;
}

sub gen_doc_html {
    my $trouble_level = p_start;
    my %pars          = convert_to_named_params \@_;
    
    my $source_dir    = npar -source_dir  => ExistingDir  => \%pars;
    my $html_dir      = npar -html_dir    => ExistingDir  => \%pars;

    my $source_file   = npar -source_file => ExistingFile => \%pars;
    my $html_file     = npar -html_file   => Filled       => \%pars;
    
    p_end \%pars;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------
 
    my $gen_html_file = 1;
 
    if (-f $html_file) {
        my $source_date = stat($source_file)->mtime;
        my $html_date   = stat($html_file  )->mtime;
        # say "source_date $source_date";
        # say "html_date   $html_date";
        $gen_html_file = 0 if $source_date < $html_date;
    }
    
    if ($gen_html_file) {
        make_path(dirname($html_file));
        say "gen doc for $html_file";

        pod2html(
                 "--podpath=lib:ext:pod:vms",
                 "--podroot=$source_dir",
                 "--htmlroot=$html_dir",
                 "--recurse",
                 "--infile=$source_file",
                 "--outfile=$html_file");

    }
}

sub create_class_overview_report {
    my $trouble_level     = p_start;
    
    my $current_namespace = par current_namespace => Scalar => shift;
    
    p_end \@_;
 
    return undef if validation_trouble($trouble_level);
    
    # --- run sub -----------------------------------------------
    
    
    my $framework = Report::Porf::Framework::get();
    my $report    = $framework->create_report('html');
    
    # $report->cc(-h => 'ID',        -w =>  5,  -vn => 'ID',
    #                                -a => 'r', -f  => "%5d"
    # );
    $report->cc(-h => 'PerlVers', -w =>  5,  -a  => 'l',   -vn  => 'perl_vers');
    $report->cc(-h => '#subs',    -w =>  5,  -v  => sub { scalar (keys($_[0]->{subs})); },
                                  -a => 'r', -f  => "%3d"
    );
    $report->cc(-h => 'Name (Methods)',      -w => 30,  -a  => 'c',    -esc => 0,
                -v => sub { '<a href="' . prepare_url($_[0]->{_html_file}) .'">'
                                        . $_[0]->{classname}  . '</a>'; 
                          }
    );              
    $report->cc(-h => 'Doc', -w => 3, -a  => 'c', -esc => 0,
                -v => sub { build_doc_filename($_[0]->{fullname}); }
    );              
    $report->cc(-h => 'Location',  -w =>  8,   -a => 'c', -vn  => 'location');
    $report->cc(-h => 'Namespace', -w => 30, -esc =>   0,
                -v  => sub { build_namespace_links_down($current_namespace, $_[0]->{'namespace'}); 
                           }
    );
    $report->cc(-h => '#Line',     -w =>  5,  -v  => '$_[0]->{line_nbr} || 0',
                                   -a => 'r', -f  => "%5d"
    );
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
    
    my @dirs_up;
    @dirs_up = split (/::?/, $start_dir) if $start_dir;
    my $dir_up  = join('/', map { ".." } @dirs_up);
    $dir_up    .= '/' if $dir_up;
    
    my $namespace_html = "";
    
    my $dir_down = "";
    foreach my $part (split (/::?/, $namespace)) {
        $dir_down       .= $part;
        $namespace_html .= "<a href='$dir_up$dir_down/_index.html'>$part</a>::";
        $dir_down       .= '/';
    }
    
    $namespace_html =~ s/::$//;
    
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

    tack;
    TRACE_HERE {Level => 3};
    	TRACE "report $html_file ... ";
    
    my @method_list;
    foreach my $method_name (sort(keys %{$class_info->{subs}})) {
        my $method_info = $class_info->{subs}->{$method_name};
        push (@method_list, $method_info);
    }

    my $framework = Report::Porf::Framework::get();
    my $report    = $framework->create_report('html');
    
    $report->cc(-h => 'ID',    -w =>  5,  -vn => 'ID',   -a => 'r', -f  => "%5d");
    $report->cc(-h => '#Line', -w =>  5,  -v  => '$_[0]->{line_nbr} || 0',
                               -a => 'r', -f  => "%5d");
    $report->cc(-h => '***',   -w =>  1,  -v => 'return ""; ');
    $report->cc(-h => 'Name',  -w => 30,  -vn => 'name');
    
    $report->configure_complete();
    
    my $done = eval {
	       
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
        my $doc_file_link = build_doc_filename($fullname);
        say $report_file_handle "Documentation: $doc_file_link" if $doc_file_link;
        say $report_file_handle '<h4>Subs listed: '.scalar(@method_list).'</h4>';
    
        print $report_file_handle $report->get_table_start();
    
        print $report_file_handle $report->get_header_output();
       
        $report->write_table(\@method_list, $report_file_handle);
    
        say $report_file_handle $report->get_table_end();

        say $report_file_handle '</body>';
        say $report_file_handle '</html>';

	       # TRACE "Done";
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
    tack;

        my $class_info_list = $meta_perl_info_service
        ->select_class_objects('^'.$namespace.'::\w+$');
 
    TRACE "generate overview of namespace $namespace ... with "
            .scalar(@$class_info_list)." classes ... ";
    
    my $report         = create_class_overview_report($namespace);
    my $namespace_path = $namespace || '.';
    $namespace_path    =~ s{::}{/}og;
    foreach my $lib_dir (keys(%special_dirs)) {
        my $report_file    = create_path_for_file(
            "$html_output_path/$lib_dir/$namespace_path/_index.html"
        );
        
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
    TRACE {Level => 10}, "    Done";
	   1;
}

prepare_html_filenames(fullname => $class_info_list);
prepare_namespace_html_filenames($namespace_info_list);

report_class_overview_list($class_info_list);

print "# report class infos ...\n# ";

foreach my $class_info (@$class_info_list) {
    report_class_methods($class_info);
}

print "\n# report namespace infos ...\n# ";

my @namespace_keys = map { 
    $_->{name};
} @$namespace_info_list;

foreach my $namespace (@namespace_keys) {
    next unless $namespace;    
    report_namespace($namespace);
}

TRACE '# === All done at ' . localtime() . ' ========================';

unless ($trace_mode eq 'print') {
    say '';
    say '# === All done. ========================';
}

1;

__END__

=head1 NAME

meta_scan.pl - Pure perl tool to extract meta data from perl source code

Scan dirs with perl source code for packages and subs,
fill this meta information into a PQL::Cache and
dump it to file system

=head1 VERSION

This documentation refers to version 0.101 of meta_report.pl

=head1 SYNOPSIS

  meta_report.pl <config_file.pl>
  
All parameters are defined in the config file, which is a simple Perl file:

  package MyConfig;

  my $root_dir = '/storage/emulated/legacy';

  sub get {
      return {
          -perl_meta_db_file => "$root_dir/perl_sw/info/perl_meta_dump.pl.dump",
          -cpan_lib_path     => "$root_dir/CCTools/Perl/CPAN/lib",
          # -perl_lib_path     => '.',
      };
  }

  1;
  
Create your own config file by copy of android.cfg.pl

=head1 DESCRIPTION

Just create config file and start script. Wait some seconds.

Wait a little longer if database contains infos about local CPAN/Perl installation.

Thats all!

=head2 What is generated

1 html file per module

1 html file per namespace/directory

