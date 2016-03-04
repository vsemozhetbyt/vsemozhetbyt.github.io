#!perl
################################################################################
use strict;
use warnings;
use POSIX ();
$|=1;
################################################################################
sub timecode2ms {
	my $timecode = shift;
	my @timeParts = split(/:|,/, $timecode);
	my $ms =
		$timeParts[3] +
		$timeParts[2]*1000 +
		$timeParts[1]*60000 +
		$timeParts[0]*3600000;
	return $ms;
}
################################################################################
sub ms2timecode {
	my $ms = shift;
	my $timecode =
		POSIX::floor($ms / 3600000) . ":" .
		POSIX::floor(($ms % 3600000) / 60000) . ":" .
		POSIX::floor(($ms % 60000) / 1000) . "," .
		POSIX::floor($ms % 1000);
	$timecode =~ s/\b(\d)\b/0$1/g;
	$timecode =~ s/,(\d\d)\b/,0$1/;
	return $timecode;
}
################################################################################
my $inputFileName = shift();
if (!$inputFileName) {
	print "\nEnter file to process: ";
	chomp($inputFileName = <STDIN>);
	if (!$inputFileName) {
		exit();
	}
}

if ($inputFileName !~ /\.srt$/i) {
	die "Wrong file!\n";
}

(my $outputFileName = $inputFileName) =~ s/\.srt$/.long.srt/i;

print "\nProcessing. Plese wait...";
open(INPUT_FILE, '<:encoding(utf8)', $inputFileName) or die "Cannot read from $inputFileName: $!\n";
open(OUTPUT_FILE, '>:encoding(utf8)', $outputFileName) or die "Cannot write to $outputFileName: $!\n";
################################################################################
my $txt;
{local $/; $txt = <INPUT_FILE>}
$txt =~ s/\n\n$//;
################################################################################
my @subts = split(/\n\n/, $txt);
for my $i (0 .. $#subts) {
	$subts[$i] = [split(/\n/, $subts[$i])];
	$subts[$i][1] = [split(/ --> /, $subts[$i][1])];
	$subts[$i][1][0] = timecode2ms($subts[$i][1][0]);
	$subts[$i][1][1] = timecode2ms($subts[$i][1][1]);
}
$subts[0][1][0] = ms2timecode($subts[0][1][0]);
for my $i (0 .. $#subts-1) {
	my $curEnd = $subts[$i][1][1];
	my $nextStart = $subts[$i+1][1][0];
	my $gap = $nextStart - $curEnd - 1;
	if ($gap > 0) {
		$curEnd += $gap;
	}
	$subts[$i][1][1] = ms2timecode($curEnd);
	$subts[$i+1][1][0] = ms2timecode($nextStart);
}
$subts[$#subts][1][1] = ms2timecode($subts[$#subts][1][1]);
for my $i (0 .. $#subts) {
	$subts[$i][1] = join(" --> ", @{$subts[$i][1]});
	$subts[$i] = join("\n", @{$subts[$i]});
}
################################################################################
print(OUTPUT_FILE join("\n\n", @subts));
################################################################################
close(INPUT_FILE);
close(OUTPUT_FILE);
################################################################################
