#!perl -T
################################################################################/usr/bin/
use strict;
use warnings;
use utf8;
use Encode;
use URI::Escape;
use CGI qw(:standard escapeHTML);
use CGI::Carp;
################################################################################
$CGI::POST_MAX=1024 * 1000;
$CGI::DISABLE_UPLOADS = 1;

$|=1;
binmode(STDOUT, ':encoding(UTF-8)');

chdir('..');
################################################################################
my $warning = '';
my $summary = '';
my $output = '';

my %options_labels = (
	vowels_next => 'Скопления соседних гласных',
		vowels_next_min => 'Минимальное количество звуков:',
	consonants_next => 'Скопления соседних согласных',
		consonants_next_min => 'Минимальное количество звуков:',
	sibilants_distributed => 'Скопления свистящих/шипящих',
		sibilants_distributed_min => 'Минимальное количество участков со свистящими/шипящими:',
		sibilants_distributed_gap => 'Максимальное расстояние между ними:',
	words_dub => 'Одинаковые слова',
		words_dub_min => 'Минимальный размер слова:',
		words_dub_gap => 'Максимальное расстояние между повторами:',
	beginnings_dub => 'Слова с одинаковыми началами',
		beginnings_dub_min => 'Минимальный размер совпадающего начала:',
		beginnings_dub_gap => 'Максимальное расстояние между повторами:',
	endings_dub => 'Слова с одинаковыми окончаниями',
		endings_dub_min => 'Минимальный размер совпадающего окончания:',
		endings_dub_gap => 'Максимальное расстояние между повторами:',
	combinations_dub => 'Одинаковые звукосочетания',
		combinations_dub_min => 'Минимальный размер совпадающего элемента:',
		combinations_dub_max => 'Максимальный размер совпадающего элемента:',
		combinations_dub_gap => 'Максимальное расстояние между повторами:',
	lexical_phonetic_stat => 'Лексическая и фонетическая статистика',
	user_pattern => 'Совпадения с шаблоном'
);

my %main_options = (
	txt => '',
	action => 'vowels_next',
	vowels_next => '',
	consonants_next => '',
	sibilants_distributed => '',
	words_dub => '',
	beginnings_dub => '',
	endings_dub => '',
	combinations_dub => '',
	lexical_phonetic_stat => '',
	user_pattern => ''
);

my %regexps_options = (
	vowels_next_min =>				4,	#2-10
	consonants_next_min =>			4,	#2-10
	sibilants_distributed_min =>	4,	#2-50
	sibilants_distributed_gap =>	1,	#0-50
	words_dub_min =>				3,	#1-50
	words_dub_gap =>				100,#0-3000
	beginnings_dub_min =>			3,	#1-50
	beginnings_dub_gap =>			50,	#0-3000
	endings_dub_min =>				3,	#1-50
	endings_dub_gap =>				25,	#0-3000
	combinations_dub_min =>			4,	#1-10
	combinations_dub_max =>			10,	#1-10
	combinations_dub_gap =>			25,	#0-3000
	user_pattern_txt =>				''
);

my (%user_options, $user_options_to_log);
foreach my $user_option (param()) {
	$user_options{$user_option} = decode('utf8', param($user_option));
	$user_options_to_log .=
		($user_option eq 'txt')? 'txt: ' . substr($user_options{'txt'}, 0, 100) . ' (' . length($user_options{'txt'}) . ") \t":
		"$user_option: $user_options{$user_option}\t";
}

if (defined($user_options{'txt'})) {
	$user_options_to_log =~ s/\r\n|[\r\n]/ /g;
	$user_options_to_log =~ s/\t$//g;
	foreach my $key (keys %regexps_options) {
		if (defined($user_options{$key}) && $key ne 'user_pattern_txt') {
			$user_options{$key} =~ s/\D//g;
		}
	}
	my $corrected = 0;
	if (defined($user_options{'vowels_next_min'})) {
		if ($user_options{'vowels_next_min'} < 2) {$user_options{'vowels_next_min'} = 2; $corrected = 1;}
		elsif ($user_options{'vowels_next_min'} > 10) {$user_options{'vowels_next_min'} = 10; $corrected = 1;}
	}
	if (defined($user_options{'consonants_next_min'})) {
		if ($user_options{'consonants_next_min'} < 2) {$user_options{'consonants_next_min'} = 2; $corrected = 1;}
		elsif ($user_options{'consonants_next_min'} > 10) {$user_options{'consonants_next_min'} = 10; $corrected = 1;}
	}
	if (defined($user_options{'sibilants_distributed_min'})) {
		if ($user_options{'sibilants_distributed_min'} < 2) {$user_options{'sibilants_distributed_min'} = 2; $corrected = 1;}
		elsif ($user_options{'sibilants_distributed_min'} > 50) {$user_options{'sibilants_distributed_min'} = 50; $corrected = 1;}
	}
	if (defined($user_options{'sibilants_distributed_gap'})) {
		if ($user_options{'sibilants_distributed_gap'} < 0) {$user_options{'sibilants_distributed_gap'} = 0; $corrected = 1;}
		elsif ($user_options{'sibilants_distributed_gap'} > 50) {$user_options{'sibilants_distributed_gap'} = 50; $corrected = 1;}
	}
	if (defined($user_options{'words_dub_min'})) {
		if ($user_options{'words_dub_min'} < 1) {$user_options{'words_dub_min'} = 1; $corrected = 1;}
		elsif ($user_options{'words_dub_min'} > 50) {$user_options{'words_dub_min'} = 50; $corrected = 1;}
	}
	if (defined($user_options{'words_dub_gap'})) {
		if ($user_options{'words_dub_gap'} < 0) {$user_options{'words_dub_gap'} = 0; $corrected = 1;}
		elsif ($user_options{'words_dub_gap'} > 3000) {$user_options{'words_dub_gap'} = 3000; $corrected = 1;}
	}
	if (defined($user_options{'beginnings_dub_min'})) {
		if ($user_options{'beginnings_dub_min'} < 1) {$user_options{'beginnings_dub_min'} = 1; $corrected = 1;}
		elsif ($user_options{'beginnings_dub_min'} > 50) {$user_options{'beginnings_dub_min'} = 50; $corrected = 1;}
	}
	if (defined($user_options{'beginnings_dub_gap'})) {
		if ($user_options{'beginnings_dub_gap'} < 0) {$user_options{'beginnings_dub_gap'} = 0; $corrected = 1;}
		elsif ($user_options{'beginnings_dub_gap'} > 3000) {$user_options{'beginnings_dub_gap'} = 3000; $corrected = 1;}
	}
	if (defined($user_options{'endings_dub_min'})) {
		if ($user_options{'endings_dub_min'} < 1) {$user_options{'endings_dub_min'} = 1; $corrected = 1;}
		elsif ($user_options{'endings_dub_min'} > 50) {$user_options{'endings_dub_min'} = 50; $corrected = 1;}
	}
	if (defined($user_options{'endings_dub_gap'})) {
		if ($user_options{'endings_dub_gap'} < 0) {$user_options{'endings_dub_gap'} = 0; $corrected = 1;}
		elsif ($user_options{'endings_dub_gap'} > 3000) {$user_options{'endings_dub_gap'} = 3000; $corrected = 1;}
	}
	if (defined($user_options{'combinations_dub_min'})) {
		if ($user_options{'combinations_dub_min'} < 1) {$user_options{'combinations_dub_min'} = 1; $corrected = 1;}
		elsif ($user_options{'combinations_dub_min'} > 10) {$user_options{'combinations_dub_min'} = 10; $corrected = 1;}
	}
	if (defined($user_options{'combinations_dub_max'})) {
		if ($user_options{'combinations_dub_max'} < 1) {$user_options{'combinations_dub_max'} = 1; $corrected = 1;}
		elsif ($user_options{'combinations_dub_max'} > 10) {$user_options{'combinations_dub_max'} = 10; $corrected = 1;}
	}
	if (defined($user_options{'combinations_dub_gap'})) {
		if ($user_options{'combinations_dub_gap'} < 0) {$user_options{'combinations_dub_gap'} = 0; $corrected = 1;}
		elsif ($user_options{'combinations_dub_gap'} > 3000) {$user_options{'combinations_dub_gap'} = 3000; $corrected = 1;}
	}
	if ($corrected) {
		$warning = "Некоторые настройки были округлены до установленных границ. Допустимые значения полей можно узнать из всплывающих подсказок.<br>";
	}
	$user_options{'txt'} =~ s/^\s+$//;
	$user_options{'txt'} =~ s/\x0d\x0a/\x0a/g;
	my $txtlen = length($user_options{'txt'});
	if ($txtlen > 41000) {
		$main_options{'txt'} = substr($main_options{'txt'}, 0, 41000);
		$warning .= "Ваш текст ($txtlen знаков) сокращён 41.000 знаков.<br>";
	}
	foreach my $key (keys %main_options) {
		$main_options{$key} = $user_options{$key} || '';
	}
	foreach my $key (keys %regexps_options) {
		if (defined($user_options{$key})) {
			$regexps_options{$key} = $user_options{$key};
		}
	}
	undef %user_options;
}

$main_options{$main_options{'action'}} = 'checked';

my %regexps;
my $txt_escaped = escapeHTML($main_options{'txt'});
################################################################################
if ($main_options{'txt'} ne '') {
	if ($regexps_options{'combinations_dub_min'} > $regexps_options{'combinations_dub_max'}) {
		$warning .= 'Минимальный параметр не может быть больше максимального.<br>';
	}
	elsif ($main_options{'action'} eq 'lexical_phonetic_stat') {
		get_statistics();
	}
	elsif ($main_options{'action'} eq 'user_pattern') {
		$regexps_options{'user_pattern_txt'} =~ s/^\s+$//g;
		if (!$regexps_options{'user_pattern_txt'} || $regexps_options{'user_pattern_txt'} eq '') {
			$warning .= 'Пожалуйста, введите шаблон.<br>';
		}
		else {
			if ($regexps_options{'user_pattern_txt'} =~ /[^\w\s\'-]/) {
				my $re;
				eval {$re = qr/$regexps_options{'user_pattern_txt'}/im};
				my $re_err = decode('utf8', $@);
				
				if ($re_err) {
					$warning .= "Ошибка в регулярном выражении.<br>";
				}
				else {
					$regexps_options{'user_pattern_txt'} = $re;
					$warning .= 'Шаблон воспринят как регулярное выражение.<br>';
					get_statistics();
				}
			}
			else {
				my %forms;
				foreach my $form (split(' ', $regexps_options{'user_pattern_txt'})) {
					$forms{$form}++;
				}
				$regexps_options{'user_pattern_txt'} = '\b(?:' . join('|', sort(keys(%forms))) . ')\b';
				$regexps_options{'user_pattern_txt'} = qr/$regexps_options{'user_pattern_txt'}/i;
				$warning .= 'Шаблон воспринят как список словоформ.<br>';
				get_statistics();
			}
		}
	}
	else {
		%regexps = (
			vowels_next => qr/[aeiouаеиоуыэюяё]{$regexps_options{'vowels_next_min'},}/,
			consonants_next => qr/[bcdfghjklmnpqrstvwxzбвгджзйклмнпрстфхцчшщ]{$regexps_options{'consonants_next_min'},}/,
			sibilants_distributed => qr/(?:(?:ch|sh|[csxzжзсцчшщ])+[^csxzжзсцчшщ]{0,$regexps_options{'sibilants_distributed_gap'}}?){$regexps_options{'sibilants_distributed_min'},}/,
			words_dub => qr/\b(\w{$regexps_options{'words_dub_min'},})\b\W*(?:\w\W*){0,$regexps_options{'words_dub_gap'}}?\b(\1)\b/,
			beginnings_dub => qr/\b(\w{$regexps_options{'beginnings_dub_min'},})\w*\b\W+(?:\w\W*){0,$regexps_options{'beginnings_dub_gap'}}?\b(\1)/,
			endings_dub => qr/(\w{$regexps_options{'endings_dub_min'},})\b\W*(?:\w\W*){0,$regexps_options{'endings_dub_gap'}}?\b\w*?(\1)\b/,
			combinations_dub => qr/(\w{$regexps_options{'combinations_dub_min'},$regexps_options{'combinations_dub_max'}})\w{0,$regexps_options{'combinations_dub_gap'}}?(\1)/
		);
		get_statistics();
	}
}
################################################################################
my $t_span = time() - $^T;
my $t_title = $t_span? "Обработано за $t_span сек." : '';
my $hr = $summary? '<hr>' : '';
################################################################################
print(
	header(-charset=>'UTF-8'),
	<<"EOF"
<!DOCTYPE html PUBLIC '-//W3C//DTD HTML 4.01 Transitional//EN' 'http://www.w3.org/TR/html4/loose.dtd'>
<html>
	<head>
		<meta http-equiv='Content-Type' content='text/html; charset=UTF-8'>
		<title>Проторедактор</title>
		<style type="text/css">
			body {font-family: monospace; overflow: scroll;}
			a {color: inherit;}
			fieldset, input, label {margin: 5px;}
			img {vertical-align: bottom; border: 0pt none;}
			td {vertical-align: text-top; white-space: pre;}
			.click {text-decoration: underline; cursor: pointer;}
			.help {font-style: italic;}
			.warning {color: red;}
			#contact {float: right; white-space: nowrap; margin: 0px 0px 5px 0px;}
			#help, #settings {margin: 10px 0px; border: 1px solid black; padding: 10px}
			#output {padding: 10px;}
			#reset {margin: 5px 5px 10px 5px;}
			#summary span, #output span {background-color: silver;}
			#output *[class] {border-left: 1px solid red;}
		</style>
		<script type='text/javascript'>
			var check_and_save_enabled = true;
			var localStorage_and_JSON = (typeof(localStorage) != 'undefined' && typeof(JSON) != 'undefined');
			var txt_form, output, pointer, pointer_end, dub, dub_end;

			function init() {
				txt_form = document.getElementById('txt_form');
				if (localStorage_and_JSON && localStorage.protoeditor_options) {
					var options = JSON.parse(localStorage.protoeditor_options);
					for (var i = 0, elem;  elem = txt_form.elements[i]; i++) {
						if (elem.name && options[elem.name] !== undefined) {
							if (elem.type == 'radio') {
								elem.checked = (elem.value == options[elem.name]);
							}
							else {
								elem.value = options[elem.name];
							}
						}
					}
				}
				check_activity();
				output = document.getElementById('output');
			}

			function reset_options() {
				var options = {
					txt:						(txt_form.elements['txt'].value || ''),
					action:						'vowels_next',
					vowels_next_min:			'4',
					consonants_next_min:		'4',
					sibilants_distributed_min:	'4',
					sibilants_distributed_gap:	'1',
					words_dub_min:				'3',
					words_dub_gap:				'100',
					beginnings_dub_min:			'3',
					beginnings_dub_gap:			'50',
					endings_dub_min:			'3',
					endings_dub_gap:			'25',
					combinations_dub_min:		'4',
					combinations_dub_max:		'10',
					combinations_dub_gap:		'25',
					user_pattern_txt:			''
				}
				if (localStorage_and_JSON) {
					localStorage.protoeditor_options = JSON.stringify(options);
				}
				for (var i = 0, elem;  elem = txt_form.elements[i]; i++) {
					if (elem.name && options[elem.name] !== undefined) {
						if (elem.type == 'radio') {
							elem.checked = (elem.value == options[elem.name]);
						}
						else {
							elem.value = options[elem.name];
						}
					}
				}
				check_activity();
			}

			function check_and_save_options() {
				if (!check_and_save_enabled) {
					return;
				}
				var warning = '';
				var corrected = false;
				for (var i = 0, elem;  elem = txt_form.elements[i]; i++) {
					if (elem.name && elem.name == 'user_pattern_txt') {
						elem.value = elem.value.replace(/\\s+/g, ' ').replace(/^\\s+\$/g, '');
					}
					else if (elem.name && elem.type == 'text') {
						elem.value = elem.value.replace(/\\D/g, '');
						if (elem.name == 'vowels_next_min') {
							if (!elem.value || Number(elem.value) < 2) {elem.value = 2;corrected = true;}
							else if (Number(elem.value) > 10) {elem.value = 10;corrected = true;}
						}
						if (elem.name == 'consonants_next_min') {
							if (!elem.value || Number(elem.value) < 2) {elem.value = 2;corrected = true;}
							else if (Number(elem.value) > 10) {elem.value = 10;corrected = true;}
						}
						if (elem.name == 'sibilants_distributed_min') {
							if (!elem.value || Number(elem.value) < 2) {elem.value = 2;corrected = true;}
							else if (Number(elem.value) > 50) {elem.value = 50;corrected = true;}
						}
						if (elem.name == 'sibilants_distributed_gap') {
							if (!elem.value || Number(elem.value) < 0) {elem.value = 0;corrected = true;}
							else if (Number(elem.value) > 50) {elem.value = 50;corrected = true;}
						}
						if (elem.name == 'words_dub_min') {
							if (!elem.value || Number(elem.value) < 1) {elem.value = 1;corrected = true;}
							else if (Number(elem.value) > 50) {elem.value = 50;corrected = true;}
						}
						if (elem.name == 'words_dub_gap') {
							if (!elem.value || Number(elem.value) < 0) {elem.value = 0;corrected = true;}
							else if (Number(elem.value) > 3000) {elem.value = 3000;corrected = true;}
						}
						if (elem.name == 'beginnings_dub_min') {
							if (!elem.value || Number(elem.value) < 1) {elem.value = 1;corrected = true;}
							else if (Number(elem.value) > 50) {elem.value = 50;corrected = true;}
						}
						if (elem.name == 'beginnings_dub_gap') {
							if (!elem.value || Number(elem.value) < 0) {elem.value = 0;corrected = true;}
							else if (Number(elem.value) > 3000) {elem.value = 3000;corrected = true;}
						}
						if (elem.name == 'endings_dub_min') {
							if (!elem.value || Number(elem.value) < 1) {elem.value = 1;corrected = true;}
							else if (Number(elem.value) > 50) {elem.value = 50;corrected = true;}
						}
						if (elem.name == 'endings_dub_gap') {
							if (!elem.value || Number(elem.value) < 0) {elem.value = 0;corrected = true;}
							else if (Number(elem.value) > 3000) {elem.value = 3000;corrected = true;}
						}
						if (elem.name == 'combinations_dub_min') {
							if (!elem.value || Number(elem.value) < 1) {elem.value = 1;corrected = true;}
							else if (Number(elem.value) > 10) {elem.value = 10;corrected = true;}
						}
						if (elem.name == 'combinations_dub_max') {
							if (!elem.value || Number(elem.value) < 1) {elem.value = 1;corrected = true;}
							else if (Number(elem.value) > 10) {elem.value = 10;corrected = true;}
						}
						if (elem.name == 'combinations_dub_gap') {
							if (!elem.value || Number(elem.value) < 0) {elem.value = 0;corrected = true;}
							else if (Number(elem.value) > 3000) {elem.value = 3000;corrected = true;}
						}
					}
				}
				if (corrected) {
					warning = 'Некоторые настройки были округлены до установленных границ.\\nДопустимые значения полей можно узнать из всплывающих подсказок.\\n\\n';
				}
				txt_form['txt'].value = txt_form['txt'].value.replace(/^\\s+\$/, '').replace(/\\x0d\\x0a/g, '\\x0a');
				var txtlen = txt_form.elements['txt'].value.length;
				if (txtlen > 41000) {
					txt_form.elements['txt'].value = txt_form.elements['txt'].value.substr(0, 41000);
					warning += ('Ваш текст (' + txtlen + ' знаков) сокращён до 41.000 знаков.');
				}
				if (warning) {
					alert(warning);
				}
				if (localStorage_and_JSON) {
					var options = {};
					for (var i = 0, elem;  elem = txt_form.elements[i]; i++) {
						if (elem.name) {
							if (elem.type == 'radio') {
								if (elem.checked) {
									options[elem.name] = elem.value;
								}
							}
							else {
								options[elem.name] = elem.value || '';
							}
						}
					}
					localStorage.protoeditor_options = JSON.stringify(options);
				}
			}

			function on_submit() {
				check_and_save_options();
				if (txt_form.elements['txt'].value == '') {
					alert('Пожалуйста, введите текст.');
					return false;
				}
				else if (
					document.getElementById('combinations_dub').checked &&
					Number(txt_form.elements['combinations_dub_min'].value) > Number(txt_form.elements['combinations_dub_max'].value)
				) {
					txt_form.elements['combinations_dub_min'].focus();
					alert('Минимальный параметр не может быть больше максимального.');
					return false;
				}
				else if (
					document.getElementById('user_pattern').checked &&
					txt_form.elements['user_pattern_txt'].value == ''
				) {
					txt_form.elements['user_pattern_txt'].focus();
					alert('Пожалуйста, введите шаблон.');
					return false;
				}
				else {
					check_and_save_enabled = false;
					return true;
				}
			}

			function change_visibility(id) {
				var elem = document.getElementById(id);
				if (elem.style.display == 'none') {
					elem.style.display = 'block';
				}
				else {
					elem.style.display = 'none';
				}
			}

			function check_activity() {
				var inputs = txt_form.getElementsByTagName('input');
				for (var i = 0, input;  input = inputs[i]; i++) {
					if (input.type == 'text') {
						input.disabled = !document.getElementById(input.getAttribute('handler')).checked;
					}
				}
			}

			function navigate(event) {
				var target = event.target || event.srcElement;
				if (
					document.getElementById('s1') &&
					target.tagName.toLowerCase() != 'textarea' &&
					target.tagName.toLowerCase() != 'input' &&
					(event.keyCode == 32 || event.charCode == 32)
				) {
					if(event.preventDefault) {
						event.preventDefault();
					}
					else {
						event.returnValue = false;
					}
					if (!pointer) {
						pointer = document.getElementById('s1');
					}
					else {
						pointer.removeAttribute('class');
						pointer_end.removeAttribute('class');
						if (dub) {
							dub.removeAttribute('class');
							dub_end.removeAttribute('class');
						}
						if (event.shiftKey) {
							var prevId = 's' + (Number(pointer.id.replace(/\\D/g, '')) - 1);
							if (document.getElementById(prevId)) {
								pointer = document.getElementById(prevId);
							}
						}
						else {
							var nextId = 's' + (Number(pointer.id.replace(/\\D/g, '')) + 1);
							if (document.getElementById(nextId)) {
								pointer = document.getElementById(nextId);
							}
						}
					}
					pointer_end = document.getElementById(pointer.id.replace(/s/, 'e'));
					pointer.className = pointer_end.className = 'pointer';
					dub = document.getElementById(pointer.id + '-2');
					if (dub) {
						dub_end = document.getElementById(dub.id.replace(/s/, 'e'));
						dub.className = dub_end.className = 'dub';
					}
					pointer.scrollIntoView(true);
				}
			}

			function set_current_match(event) {
				var target = event.target || event.srcElement;
				if (target.tagName.toLowerCase() == 'span') {
					if (pointer) {
						pointer.removeAttribute('class');
						pointer_end.removeAttribute('class');
						if (dub) {
							dub.removeAttribute('class');
							dub_end.removeAttribute('class');
						}
					}
					if (target.id.indexOf('-2') < 0) {
						pointer = target;
					}
					else {
						if (pointer) {
							pointer = document.getElementById(target.id.replace(/-2/, ''));
						}
						else {
							pointer = document.getElementById('s1');
						}
					}
					pointer_end = document.getElementById(pointer.id.replace(/s/, 'e'));
					pointer.className = pointer_end.className = 'pointer';
					dub = document.getElementById(pointer.id + '-2');
					if (dub) {
						dub_end = document.getElementById(dub.id.replace(/s/, 'e'));
						dub.className = dub_end.className = 'dub';
					}
				}
			}
		</script>
	</head>
	<body onload='init();' onunload='check_and_save_options();' onkeypress='navigate(event);'>
		<div id='contact'>
			<img alt='' src='data:image/gif;base64,R0lGODlhFAASAOZIAAkyZQkyZAkxZJ7P/22d2G6m2BpLhf///8fHx0x8t/3VmTJTfSNThafX/02FtixclhNDfX628ouMhBtLfTpTfafY/3p6ehI6bfzNmvXNmnWm4J7O/yNTjUV8uEx7t1yVz3SEjVN0lYNjfE18uDttniNDbf3WmnladJ/X/0tjfIpjfKfe/4yMjMXFxUtsjgQiW7Sli1SEtitUjl2WyCtcl4uEenWm2G2dz5/Y//3emU6OyObFkt28klyUyKjf/wsyZU2FuINje0Njhf3VmnlbdH226RpKfVuMxwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAEgALAAAAAAUABIAAAeggEiCg4SFhoMCAAABh40AJyoUAAKNhQFEQSEHCD8AlYgiQgcHLiQGjJ8BCwgIF0crGwyUlYotCzQ9KA0DDKiNASUPGh4OAxUDMp6VARMEBSMxA7scs44GzglAAz44D8qNAtcFDglFETMv34cBRjc2HSkSMDXqhwIQBB8gJjk89esQdLBQgEGBr1QCLOwYkmHSp0EBAixadPChIEX/LBIKBAA7'>
			<a href='http://homo-nudus.livejournal.com/204416.html?format=light'>Для связи</a>
		</div>
		<div id='header'>
			<p id='prompt' title='$t_title'>
				Введите текст не больше авторского листа (40.000 знаков + 1.000 знаков про запас).<br>
				В настройках выберите вид разбора. По мере необходимости уточняйте параметры.
			</p>
			<form id='txt_form' method='post' action='protoeditor.pl' enctype='application/x-www-form-urlencoded' onsubmit='return on_submit();'>
				<textarea name='txt' cols='80' rows='10'>$txt_escaped</textarea>
				<div id='handlers'>
					<input type='submit' value='Отослать'>
					<span class='click' onclick='change_visibility("help")'>Справка</span>
					<span class='click' onclick='change_visibility("settings")'>Настройки</span>
				</div>
				<div id='help' class='help' style='display: none;'>
					<p>1. Текст и настройки пользователя сохраняются между сессиями в следующих браузерах: <a href='http://www.google.com/chrome/'>Chrome&nbsp;4+</a>, <a href='http://www.mozilla.com/firefox/'>Firefox&nbsp;3.5+</a>, <a href='http://www.microsoft.com/windows/internet-explorer/default.aspx'>Internet&nbsp;Explorer&nbsp;8+</a>, <a href='http://www.opera.com/'>Opera&nbsp;10.5+</a>, <a href='http://www.apple.com/safari/'>Safari&nbsp;4+</a>.</p>
					<p>2. Единица измерения для всех настроек — буква. Допустимые границы параметров можно узнать из подсказки, всплывающей над активным полем. При установлении ограничений подразумевались следующие данные: максимальный размер русского слова: <a href='http://ru.wikipedia.org/wiki/%D0%A1%D0%B0%D0%BC%D0%BE%D0%B5_%D0%B4%D0%BB%D0%B8%D0%BD%D0%BD%D0%BE%D0%B5_%D1%81%D0%BB%D0%BE%D0%B2%D0%BE_%D1%80%D1%83%D1%81%D1%81%D0%BA%D0%BE%D0%B3%D0%BE_%D1%8F%D0%B7%D1%8B%D0%BA%D0%B0'>50 букв</a>; средний размер печатной строки: 50 букв; средний размер печатной страницы: 3000 букв. При поиске звуковых скоплений и одинаковых звукосочетаний мягкий и твёрдый знаки не учитываются. Проблемные участки могут накладываться друг на друга (их подсветка может сливаться), но границы будут видны при переборе совпадений (см. пункт 5).</p>
					<p>3. Скрипт может работать очень долго при некоторых сочетаниях следующих условий: большой размер текста; большой размер допустимых расстояний; большой разрыв между минимумом и максимумом некоторых параметров. Если время превысит лимит, установленный хозяевами хостинга, сервер вернёт ошибку «Gateway Timeout». Постарайтесь в таком случае уменьшить хотя бы один из рискованных параметров, или разбить проверку на несколько запросов с разными сочетаниями настроек, или проверить текст по частям.</p>
					<p>4. При получении таблицы с лексической и фонетической статистикой для большого текста Internet&nbsp;Explorer может «подвисать».</p>
					<p>5. Переходите от совпадения к совпадению клавишами «пробел» (вперёд) или «Shift + пробел» (назад). Чтобы выбрать произвольный элемент как текущую точку отсчёта, щёлкните на нём мышкой. При поиске повторов выделяется пара перекликающихся элементов, щелкать для выбора можно на любом из них, второй будет выделен автоматически.</p>
				</div>
				<div id='settings' style='display: none;'>
					<div id='reset'><span class='click warning' onclick='reset_options();'>Сбросить настройки к умолчаниям.</span></div>
					<fieldset>
						<legend><input type='radio' $main_options{'vowels_next'} onchange='check_activity();' name='action' id='vowels_next' value='vowels_next'><label for='vowels_next'>$options_labels{'vowels_next'}</label></legend>
						<label for='vowels_next_min'>$options_labels{'vowels_next_min'}</label>&nbsp;<input type='text' handler='vowels_next' size='3' title='2 – 10' maxlength='2' name='vowels_next_min' id='vowels_next_min' value='$regexps_options{"vowels_next_min"}'>
					</fieldset>
					<fieldset>
						<legend><input type='radio' $main_options{'consonants_next'} onchange='check_activity();' name='action' id='consonants_next' value='consonants_next'}><label for='consonants_next'>$options_labels{'consonants_next'}</label></legend>
						<label for='consonants_next_min'>$options_labels{'consonants_next_min'}</label>&nbsp;<input type='text' handler='consonants_next' size='3' title='2 – 10' maxlength='2' name='consonants_next_min' id='consonants_next_min' value='$regexps_options{"consonants_next_min"}'>
					</fieldset>
					<fieldset>
						<legend><input type='radio' $main_options{'sibilants_distributed'} onchange='check_activity();' name='action' id='sibilants_distributed' value='sibilants_distributed'><label for='sibilants_distributed'>$options_labels{'sibilants_distributed'}</label></legend>
						<label for='sibilants_distributed_min'>$options_labels{'sibilants_distributed_min'}</label>&nbsp;<input type='text' handler='sibilants_distributed' size='3' title='2 – 50' maxlength='2' name='sibilants_distributed_min' id='sibilants_distributed_min' value='$regexps_options{"sibilants_distributed_min"}'><br>
						<label for='sibilants_distributed_gap'>$options_labels{'sibilants_distributed_gap'}</label>&nbsp;<input type='text' handler='sibilants_distributed' size='3' title='0 – 50' maxlength='2' name='sibilants_distributed_gap' id='sibilants_distributed_gap' value='$regexps_options{"sibilants_distributed_gap"}'>
					</fieldset>
					<fieldset>
						<legend><input type='radio' $main_options{'words_dub'} onchange='check_activity();' name='action' id='words_dub' value='words_dub'><label for='words_dub'>$options_labels{'words_dub'}</label></legend>
						<label for='words_dub_min'>$options_labels{'words_dub_min'}</label>&nbsp;<input type='text' handler='words_dub' size='3' title='1 – 50' maxlength='2' name='words_dub_min' id='words_dub_min' value='$regexps_options{"words_dub_min"}'><br>
						<label for='words_dub_gap'>$options_labels{'words_dub_gap'}</label>&nbsp;<input type='text' handler='words_dub' size='5' title='0 – 3000' maxlength='4' name='words_dub_gap' id='words_dub_gap' value='$regexps_options{"words_dub_gap"}'>
					</fieldset>
					<fieldset>
						<legend><input type='radio' $main_options{'beginnings_dub'} onchange='check_activity();' name='action' id='beginnings_dub' value='beginnings_dub'><label for='beginnings_dub'>$options_labels{'beginnings_dub'}</label></legend>
						<label for='beginnings_dub_min'>$options_labels{'beginnings_dub_min'}</label>&nbsp;<input type='text' handler='beginnings_dub' size='3' title='1 – 50' maxlength='2' name='beginnings_dub_min' id='beginnings_dub_min' value='$regexps_options{"beginnings_dub_min"}'><br>
						<label for='beginnings_dub_gap'>$options_labels{'beginnings_dub_gap'}</label>&nbsp;<input type='text' handler='beginnings_dub' size='5' title='0 – 3000' maxlength='4' name='beginnings_dub_gap' id='beginnings_dub_gap' value='$regexps_options{"beginnings_dub_gap"}'>
					</fieldset>
					<fieldset>
						<legend><input type='radio' $main_options{'endings_dub'} onchange='check_activity();' name='action' id='endings_dub' value='endings_dub'><label for='endings_dub'>$options_labels{'endings_dub'}</label></legend>
						<label for='endings_dub_min'>$options_labels{'endings_dub_min'}</label>&nbsp;<input type='text' handler='endings_dub' size='3' title='1 – 50' maxlength='2' name='endings_dub_min' id='endings_dub_min' value='$regexps_options{"endings_dub_min"}'><br>
						<label for='endings_dub_gap'>$options_labels{'endings_dub_gap'}</label>&nbsp;<input type='text' handler='endings_dub' size='5' title='0 – 3000' maxlength='4' name='endings_dub_gap' id='endings_dub_gap' value='$regexps_options{"endings_dub_gap"}'>
					</fieldset>
					<fieldset>
						<legend><input type='radio' $main_options{'combinations_dub'} onchange='check_activity();' name='action' id='combinations_dub' value='combinations_dub'><label for='combinations_dub'>$options_labels{'combinations_dub'}</label></legend>
						<label for='combinations_dub_min'>$options_labels{'combinations_dub_min'}</label>&nbsp;<input type='text' handler='combinations_dub' size='3' title='1 – 10' maxlength='2' name='combinations_dub_min' id='combinations_dub_min' value='$regexps_options{"combinations_dub_min"}'><br>
						<label for='combinations_dub_max'>$options_labels{'combinations_dub_max'}</label>&nbsp;<input type='text' handler='combinations_dub' size='3' title='1 – 10' maxlength='2' name='combinations_dub_max' id='combinations_dub_max' value='$regexps_options{"combinations_dub_max"}'><br><br>
						<label for='combinations_dub_gap'>$options_labels{'combinations_dub_gap'}</label>&nbsp;<input type='text' handler='combinations_dub' size='5' title='0 – 3000' maxlength='4' name='combinations_dub_gap' id='combinations_dub_gap' value='$regexps_options{"combinations_dub_gap"}'>
					</fieldset>
					<fieldset>
						<input type='radio' $main_options{'lexical_phonetic_stat'} onchange='check_activity();' name='action' id='lexical_phonetic_stat' value='lexical_phonetic_stat'><label for='lexical_phonetic_stat'>$options_labels{'lexical_phonetic_stat'}</label>
					</fieldset>
					<fieldset>
						<legend><input type='radio' $main_options{'user_pattern'} onchange='check_activity();' name='action' id='user_pattern' value='user_pattern'><label for='user_pattern'>$options_labels{'user_pattern'}</label></legend>
						<div class='help'>Если в шаблоне встретятся только буквы/цифры, дефисы (-), апострофы (&#39;) и пробелы, он будет воспринят как список словоформ и все его элементы будут подсвечены в тексте (без учёта регистра). Если в шаблоне встретятся другие знаки, он будет воспринят как <a href='http://ru.wikipedia.org/wiki/Регулярные_выражения'>регулярное выражение</a> (поддерживается диалект Perl; игнорирование регистра и опция многострочности по умолчанию включены).</div>
						<input type='text' handler='user_pattern' size='80' name='user_pattern_txt' id='user_pattern_txt' value='$regexps_options{"user_pattern_txt"}'>
					</fieldset>
					<input type='submit' value='Отослать'>
				</div>
			</form>
			$hr<div id='warning' class='warning'>$warning</div><div id='summary'>$summary</div>$hr
		</div>
		<div id='output' onclick='set_current_match(event);'>$output</div>
	</body>
</html>
EOF
);
################################################################################
undef $output;
undef %main_options;

my $referer = decode('utf8', uri_unescape($ENV{'HTTP_REFERER'} || '*'));
my $sript_path = "http://$ENV{HTTP_HOST}$ENV{SCRIPT_NAME}";
my $placeholder = '*' x length($sript_path);
$referer =~ s/\Q$sript_path/$placeholder/i;

if ($summary =~ /совпадений не найдено/i) {
	$summary = uc($summary);
}
else {
	$summary =~ s/<span>(\d+)<\/span>/$1/
}

if ($ENV{'REMOTE_ADDR'} ne '91.197.171.156' || !$ENV{'REMOTE_ADDR'}) {
	chdir('log') or die "Cannot find the log directory: $!\n";
	open(LOG, '>>', 'protoeditor_log.txt') or die "Cannot write to the log file: $!\n";
	binmode(LOG, ':encoding(UTF-8)');
	flock(LOG, 2);
	print(LOG
		join("\t",
			(length($ENV{'REMOTE_ADDR'}) < 12 ? "$ENV{'REMOTE_ADDR'}\t" : $ENV{'REMOTE_ADDR'}),
			scalar(localtime()),
			$t_span,
			$referer,
			$user_options_to_log || '*',
			($summary . $warning) || '*',
		),"\n"
	);
	flock(LOG, 8);
	close(LOG);
}
################################################################################
sub get_statistics {
	if ($main_options{'action'} eq 'lexical_phonetic_stat') {
		my $txt_lc = lc($main_options{'txt'});
		my (%words, %letters);
		while ($txt_lc =~ /\b([^\W\d]+(?:-[^\W\d]+|\'[^\W\d]+)*)\b/igo) {
			$words{$1}++;
		}
		while ($txt_lc =~ /([^\W\d])/igo) {
			$letters{$1}++;
		}
		if ($words{'-'}) {
			delete $words{'-'};
		}
		my $words_num = scalar(keys %words);
		my $letters_num = scalar(keys %letters);
		my $words_keys_abc =		join("\n", map("$_ — $words{$_}", sort(keys %words)));
		my $words_keys_abc_rev =	join("\n", map("$words{$_} — $_", sort({reverse($a) cmp reverse($b)} keys %words)));
		my $words_keys_num = join("\n", map("$_ — $words{$_}", sort({$words{$b} <=> $words{$a} || $a cmp $b} keys %words)));
		my $words_keys_len = join("\n", map("$_ — $words{$_}", sort({length($b) <=> length($a) || $a cmp $b} keys %words)));
		my $letters_keys_abc = join("\n", map("$_ — $letters{$_}", sort(keys %letters)));
		my $letters_keys_num = join("\n", map("$_ — $letters{$_}", sort({$letters{$b} <=> $letters{$a} || $a cmp $b} keys %letters)));

		$summary = "$options_labels{$main_options{'action'}}. Слов: $words_num, букв: $letters_num.";
		$output = join('',
			table({-border => '1', -cellspacing => '0', -cellpadding => '5', -width => '100%'},
				tbody(
					Tr(
						th('Слова по алфавиту'),
						th('Слова по окончаниям<br>(инверсионный порядок)'),
						th('Слова по частотности'),
						th('Слова по длине'),
						th('Буквы по алфавиту'),
						th('Буквы по частотности')
					),
					Tr(
						td($words_keys_abc),
						td({-style => 'text-align: right;'}, $words_keys_abc_rev),
						td($words_keys_num),
						td($words_keys_len),
						td($letters_keys_abc),
						td($letters_keys_num)
					)
				)
			)
		);
	}
	else {
		$output = $main_options{'txt'};
		$output =~ s/</\x01/g;
		$output =~ s/>/\x02/g;
		my $problems;
		if ($main_options{'action'} eq 'vowels_next' || $main_options{'action'} eq 'consonants_next') {
			$problems = get_sequences(\$output, $regexps{$main_options{'action'}});
		}
		elsif ($main_options{'action'} eq 'sibilants_distributed') {
			$problems = get_distributed(\$output, $regexps{$main_options{'action'}});
		}
		elsif ($main_options{'action'} eq 'words_dub' || $main_options{'action'} eq 'beginnings_dub' || $main_options{'action'} eq 'endings_dub') {
			$problems = get_lexical_dubs(\$output, $regexps{$main_options{'action'}});
		}
		elsif ($main_options{'action'} eq 'combinations_dub') {
			$problems = get_phonetic_dubs(\$output, $regexps{$main_options{'action'}});
		}
		elsif ($main_options{'action'} eq 'user_pattern') {
			$problems = get_user_pattern(\$output, $regexps_options{'user_pattern_txt'});
		}
		if ($problems) {
			$summary =	"$options_labels{$main_options{'action'}}: <span>$problems</span>.";
			$output =~ s/\n/\n<br>/g;
			$output =~ s/&/&amp;/g;
			$output =~ s/\x01/&lt;/g;
			$output =~ s/\x02/&gt;/g;
		}
		else {
			$summary = "$options_labels{$main_options{'action'}}: совпадений не найдено.";
			$output = '';
		}
	}
}
################################################################################
sub get_sequences {
	my ($output, $re) = @_;
	my $txt_preprocessed = lc($$output);
	$txt_preprocessed =~ s/[\Wьъ]//g;
	my (%indices_in, %indices_out);
	my $problems = 0;
	while ($txt_preprocessed =~ /$re/go) {
		$problems++;
		$indices_in{$-[0] + 1} .= "<span id='s$problems'>";
		$indices_out{$+[0]} .= "</span><a id='e$problems'></a>";
	}
	mark_by_index($output, \%indices_in, \%indices_out, qr/[^\Wьъ]/i);
	return $problems;
}
################################################################################
sub get_distributed {
	my ($output, $re) = @_;
	my $txt_preprocessed = lc($$output);
	$txt_preprocessed =~ s/[\Wьъ]//g;
	my (%indices_in, %indices_out);
	my $problems = 0;
	my $prev_end = 0;
	while ($txt_preprocessed =~ /$re/go) {
		if ($prev_end != $+[0]) {
			$problems++;
			$indices_in{$-[0] + 1} .= "<span id='s$problems'>";
			$indices_out{$+[0]} .= "</span><a id='e$problems'></a>";
			$prev_end = $+[0];
		}
		pos($txt_preprocessed) = $-[0] + 1;
	}
	mark_by_index($output, \%indices_in, \%indices_out, qr/[^\Wьъ]/i);
	return $problems;
}
################################################################################
sub get_lexical_dubs {
	my ($output, $re) = @_;
	my $txt_preprocessed = lc($$output);
	my (%indices_in, %indices_out);
	my $problems = 0;
	while ($txt_preprocessed =~ /$re/go) {
		$problems++;
		$indices_in{$-[1] + 1} .= "<span id='s$problems'>";
		$indices_out{$+[1]} .= "</span><a id='e$problems'></a>";
		$indices_in{$-[2] + 1} .= "<span id='s$problems-2'>";
		$indices_out{$+[2]} .= "</span><a id='e$problems-2'></a>";
		pos($txt_preprocessed) = $+[1];
	}
	mark_by_index($output, \%indices_in, \%indices_out, qr/./s);
	return $problems;
}
################################################################################
sub get_phonetic_dubs {
	my ($output, $re) = @_;
	my $txt_preprocessed = lc($$output);
	$txt_preprocessed =~ s/[\Wьъ]//g;
	my (%indices_in, %indices_out);
	my $problems = 0;
	my $prev_end = 0;
	my $prev_dub_end = 0;
	while ($txt_preprocessed =~ /$re/go) {
		if ($prev_end != $+[1] && $prev_dub_end != $+[2]) {
			$problems++;
			$indices_in{$-[1] + 1} .= "<span id='s$problems'>";
			$indices_out{$+[1]} .= "</span><a id='e$problems'></a>";
			$indices_in{$-[2] + 1} .= "<span id='s$problems-2'>";
			$indices_out{$+[2]} .= "</span><a id='e$problems-2'></a>";
			$prev_end = $+[1];
			$prev_dub_end = $+[2]
		}
		pos($txt_preprocessed) = $-[1] + 1;
	}
	mark_by_index($output, \%indices_in, \%indices_out, qr/[^\Wьъ]/i);
	return $problems;
}
################################################################################
sub get_user_pattern {
	my ($output, $re) = @_;
	my (%indices_in, %indices_out);
	my $problems = 0;
	while ($$output =~ /$re/go) {
		$problems++;
		$indices_in{$-[0] + 1} .= "<span id='s$problems'>";
		$indices_out{$+[0]} .= "</span><a id='e$problems'></a>";
	}
	mark_by_index($output, \%indices_in, \%indices_out, qr/./s);
	return $problems;
}
################################################################################
sub mark_by_index {
	my ($output, $indices_in, $indices_out, $step) = @_;
	my ($counter, $mem_pos);
	while ($$output =~ /$step/go) {
		$counter++;
		if ($indices_in->{$counter}) {
			$mem_pos = pos($$output);
			substr($$output, pos($$output) - 1, 0, $indices_in->{$counter});
			pos($$output) = $mem_pos + length($indices_in->{$counter});
		}
		if ($indices_out->{$counter}) {
			$mem_pos = pos($$output);
			substr($$output, pos($$output), 0, $indices_out->{$counter});
			pos($$output) = $mem_pos + length($indices_out->{$counter});
		}
	}
}
################################################################################
