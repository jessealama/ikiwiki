package IkiWiki::Plugin::table;
# by Victor Moral <victor@taquiones.net>

use warnings;
use strict;

use IkiWiki;

sub import { #{{{
	hook(type => "preprocess", id => "table", call => \&preprocess);
} # }}}

sub preprocess (@) { #{{{
	my %params =(
		format	=> 'auto',
		header	=> 'yes',
		@_
	);

	if (exists $params{file}) {
		if (! $pagesources{$params{file}}) {
			return "[[table ".gettext("cannot find file")."]]";
		}
		$params{data} = readfile(srcfile($params{file}));
	}

	if (lc $params{format} eq 'auto') {
		# first try the more simple format
		if (is_dsv_data($params{data})) {
			$params{format} = 'dsv';
		}
		else {
			$params{format} = 'csv';
		}
	}

	my @data;
	if (lc $params{format} eq 'csv') {
		@data=split_csv($params{data}, $params{delimiter});
	}
	elsif (lc $params{format} eq 'dsv') {
		@data=split_dsv($params{data}, $params{delimiter});
	}
	else {
		return "[[table ".gettext("unknown data format")."]]";
	}

	my $header;
	if (lc($params{header}) eq "yes") {
		$header=shift @data;
	}
	if (! @data) {
		return "[[table ".gettext("empty data")."]]";
	}

	my @lines;
	push @lines, defined $params{class}
			? "<table class=\"".$params{class}.'">'
			: '<table>';
	push @lines, "\t<thead>",
		genrow($params{page}, $params{destpage}, "th", @$header),
	        "\t</thead>" if defined $header;
	push @lines, "\t<tbody>";
	push @lines, genrow($params{page}, $params{destpage}, "td", @$_)
		foreach @data;
	push @lines, "\t</tbody>" if defined $header;
	push @lines, '</table>';
	my $html = join("\n", @lines);

	if (exists $params{file}) {
		return $html."\n\n".
			htmllink($params{page}, $params{destpage}, $params{file},
				linktext => gettext('Direct data download'));
	}
	else {  
		return $html;
	}            
} #}}}

sub is_dsv_data ($) { #{{{
	my $text = shift;

	my ($line) = split(/\n/, $text);
	return $line =~ m{.+\|};
}

sub split_csv ($$) { #{{{
	my @text_lines = split(/\n/, shift);
	my $delimiter = shift;

	eval q{use Text::CSV};
	error($@) if $@;
	my $csv = Text::CSV->new({ 
		sep_char	=> defined $delimiter ? $delimiter : ",",
		binary		=> 1,
	}) || error("could not create a Text::CSV object");
	
	my $l=0;
	my @data;
	foreach my $line (@text_lines) {
		$l++;
		if ($csv->parse($line)) {
			push(@data, [ $csv->fields() ]);
		}
		else {
			debug(sprintf(gettext('parse fail at line %d: %s'), 
				$l, $csv->error_input()));
		}
	}

	return @data;
} #}}}

sub split_dsv ($$) { #{{{
	my @text_lines = split(/\n/, shift);
	my $delimiter = shift;
	$delimiter="|" unless defined $delimiter;

	my @data;
	foreach my $line (@text_lines) {
		push @data, [ split(/\Q$delimiter\E/, $line, -1) ];
	}
    
	return @data;
} #}}}

sub genrow ($$$@) { #{{{
	my $page = shift;
	my $destpage = shift;
	my $elt = shift;
	my @data = @_;

	my @ret;
	push @ret, "\t\t<tr>";
	for (my $x=0; $x < @data; $x++) {
		my $cell=htmlize($page, $destpage, $data[$x]);
		my $colspan=1;
		while ($x+1 < @data && $data[$x+1] eq '') {
			$x++;
			$colspan++;
		}
		if ($colspan > 1) {
			push @ret, "\t\t\t<$elt colspan=\"$colspan\">$cell</$elt>"
		}
		else {
			push @ret, "\t\t\t<$elt>$cell</$elt>"
		}
	}
	push @ret, "\t\t</tr>";

	return @ret;
} #}}}

sub htmlize ($$$) { #{{{
	my $page = shift;
	my $destpage = shift;
	my $text = shift;

	$text=IkiWiki::htmlize($page, pagetype($pagesources{$page}),
		IkiWiki::preprocess($page, $destpage, $text));

	# hack to get rid of enclosing junk added by markdown
	$text=~s!^<p>!!;
	$text=~s!</p>$!!;
	chomp $text;

	return $text;
}

1
