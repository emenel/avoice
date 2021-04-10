// computational environment, init
(
s.options.numOutputBusChannels = 4;

s.options.sampleRate = 44100;
s.boot;
);

s.waitForBoot {
	(
		TempoClock.default.tempo = 0.5;

		// cracking contingencies
		~aCrack = Bus.audio(s);

		//all the pieces, waiting
		~searcher = {|dir|
			Array.fill(dir.files.size, {|i| [dir.files[i].fileNameWithoutExtension, Buffer.read(s, dir.pathOnly+/+dir.files[i].fileName)]});
		};
		~fragments = ~searcher.value(PathName.new(thisProcess.nowExecutingPath.dirname++"/phonemes/"));
		~environments = ~searcher.value(PathName.new(thisProcess.nowExecutingPath.dirname++"/samps/"));

		//a language for combining
		~environmentIsNumbers = ~environments.collect({|item|
			item[1].bufnum;
		});

		~languageIsNumbers = ~fragments.collect({|item|
			item[1].bufnum;
		});

		~fragmentSearcher = {|letter|
			~fragments.detect({|item| item[0]==letter })[1].bufnum;
		};

		~fragmentsConvertIntoCreation = {|phrase|
			phrase.collect({|item,i| ~fragmentSearcher.value(item)});
		};
	);

	(
		SynthDef(\aVoice, {|bufnum = 0, amp = 0, speed = 1, dur = 1, out = 0, bufstart = 10|
			var sig = PlayBuf.ar(1, bufnum, Lag3.kr(speed, dur/2), startPos: bufstart, doneAction: Done.freeSelf);
			sig = LPF.ar(in: sig, freq: 11000);
			Out.ar([out,~aCrack.index], sig*amp);
		}).add;

		SynthDef(\anEcho, {|delaytime = 5, delayfactor = 0.5, win = 0.9, out, in|
			var sig = SwitchDelay.ar(
				in: In.ar(in),
				drylevel: 0,
				wetlevel: 0.7,
				delaytime: delaytime,
				delayfactor: delayfactor,
				maxdelaytime: 20.0
			);
			sig = PitchShift.ar(in: sig, windowSize: win, pitchRatio: 1, pitchDispersion: 0.5, timeDispersion: 0.001, mul: 1, add: 0);
			Out.ar(out, sig);
		}).add;

		SynthDef(\aWorld, {|bufnum, amp, speed, position, win, out, dur, overlaps = 8, rand = 0.2, gate = 1|
			var sig = Warp1.ar(numChannels: 2,
				bufnum: bufnum,
				pointer: Lag3.kr(position, dur/3),
				freqScale: Lag3.kr(speed, dur/2),
				windowSize: Lag3.kr(win, dur/3),
				envbufnum: -1,
				overlaps: Lag3.kr(overlaps,dur/5),
				windowRandRatio: Lag3.kr(rand,dur/5),
				interp: 2);
			var env = Env.asr(dur*0.1, dur*0.8, dur*0.1, -4.0);
			sig = sig*EnvGen.kr(env, gate, doneAction: Done.freeSelf);
			Out.ar(out, sig*Lag3.kr(amp*0.4, dur/10));
		}).add;

		SynthDef(\aChorus, {|freq, out, amp, gate = 1, dur|
			var sig;
			var env = Env.asr(0.5, 1, 2, -4.0);
			sig = DynKlang.ar(`[ freq, [0.15,0.15,0.15] ], 1, 0);
			sig = Mix.new([sig, HPF.ar(WhiteNoise.ar(0.02), 15000, 1)]);
			sig = Pan2.ar(sig, FSinOsc.kr(0.25), 1)*EnvGen.kr(env, gate, doneAction: Done.freeSelf);
			Out.ar(out, sig*amp)
		}).add;
	);

	s.sync();

	// patterns and repetitions
	(
		Pdef(\aVoiceTurnedToMeaning,
			Pbind(\instrument, \aVoice,
				\speed, Pwhite(0.9,1.1,inf),
				\legato, 1.5,
				\bufnum, Pseq(~fragmentsConvertIntoCreation.value(["h","eh","l","oh"]), 1),
				\dur, Pfunc({|d|
					(s.cachedBufferAt(d.bufnum).duration-0.05);
				}),
				\amp, 0.9
			)
		);
		Pdef(\aVoiceTurnedToMeaning).fadeTime = 0.5;

		~repeater = Pmono(\anEcho, *[
			delaytime: 0.01,
			delayfactor: Pxrand([0, 0.2, 0.1, 0.5], inf),
			dur: Pxrand([0.1, 0.5, 1, 0.25], inf),
			win: Pwhite(0.2, 2, inf),
			in: ~aCrack.index,
			out: 1
		]);

		Pdef(\aSong, Pbind(\instrument, \aChorus,
			\dur, Pwhite(0.5,10,3),
			\legato, 1.05, \root, -12,
			\degree, Ptuple([Pxrand((0..12), 3), Pxrand((0..12), 3), Pxrand((0..12), 3)]),
			\amp, 0.25,
			\out, 2,
			\scale, Scale.new(#[ 0, 1, 3, 5, 7, 8, 10 ], 13))
		);

		Pdef(\worldOfCombinations, Pseq([
			Plazy({
				var length = [2, 5, 10, 15].choose;
				Pmono(\aWorld,
					\bufnum, Pxrand(~environmentIsNumbers, length),
					\amp, Pseq([Pwhite(0.2, 0.3, length-2), 0, 0], 1),
					\speed, Pwhite(0.01, 1.5, length),
					\position, Pwhite(0, 1.0, length),
					\win, Plprand(0.05, 10, length),
					\dur, Pwhite(5, 20, length),
					\rand, Plprand(0.1, 1, length),
					\overlaps, Pwhite(2, 16, length),
					\legato, 1.05,
					\out, 2
				)
			})
		], inf));

		Pdef(\aPlaceToSpeak, Pdef(\worldOfCombinations));
		Pdef(\aPlaceToSpeak).fadeTime = 2;
	);

	// practices
	(
		~piecesOfTheWorld = Pxrand([
			~fragmentsConvertIntoCreation.value(["h","eh","l","oh"]),
			~fragmentsConvertIntoCreation.value(["s","p","ee","k","ee","ng"]),
			~fragmentsConvertIntoCreation.value(["d", "ah", "n"]),
			~fragmentsConvertIntoCreation.value(["d","r","ee","m"]),
			~fragmentsConvertIntoCreation.value(["h","aw","l","t","d"]),
			~fragmentsConvertIntoCreation.value(["t","i","m"]),
			~fragmentsConvertIntoCreation.value(["s","p","oh","k","eh","n"]),
			~fragmentsConvertIntoCreation.value(["y","oo","n","ih","t","ee","s"]),
			~fragmentsConvertIntoCreation.value(["m","oh","m","eh","n","t"]),
			~fragmentsConvertIntoCreation.value(["eh","n","ch","a","n","t"]),
			~fragmentsConvertIntoCreation.value(["j","oi"]),
			~fragmentsConvertIntoCreation.value(["b","a","k","g","r","ow","n","d"]),
			~fragmentsConvertIntoCreation.value(["r","eh","p","eh","t","ih","sh","ih","n"]),
			~fragmentsConvertIntoCreation.value(["s","t","ai","s","ih","s"]),
			~fragmentsConvertIntoCreation.value(["s","p","i","r","a","l"]),
			~fragmentsConvertIntoCreation.value(["t","r","a","n","s","f","oh","r","m"]),
			~fragmentsConvertIntoCreation.value(["n","uh","th","ee","ng","n","eh","s"]),
			~fragmentsConvertIntoCreation.value(["p","a","th","s"]),
			~fragmentsConvertIntoCreation.value(["t","uh","r","t","l"])
		], inf);

		r = Routine.new({|inval|
			var ts = ~piecesOfTheWorld.asStream;
			var target = List.newUsing(ts.next);
			var newvals = List.fill(target.size, { rand(~languageIsNumbers.size) });
			var i = 0;
			var dlt = 1;
			var pause = 1;
			var initSum = (newvals-target).sum.abs;

			loop {

				if(target == newvals, {
					/* when meaning is acheived,
					sound the chorus */

					i = i+1;

					Pdef(\aPlaceToSpeak, Pdef(\aSong));

					if(i == 4, {
						i = 0;
						target = List.newUsing(ts.next);
						3.wait;

						if(target.size > newvals.size, {
							(target.size - newvals.size).do({
								newvals.add(rand(~languageIsNumbers.size));
							});
						});
						if(target.size < newvals.size, { newvals = newvals.copyRange(0,target.size-1) });

						if(newvals == target, {
							initSum = 1;
						}, {
							initSum = (newvals-target).sum.abs;
						});

						((20.rand)+10).wait;

						// the world returns
						Pdef(\aPlaceToSpeak, Pdef(\worldOfCombinations));

						((25.rand)+5).wait;

					});
				});

				target.do({ |item, j|
					var v = newvals[j];

					case
					{v == item} {v = v}
					{v > item} {v = v-dlt}
					{v < item} {v = v+dlt};

					newvals.put(j,v);
				});

				// speak
				Pbindef(\aVoiceTurnedToMeaning, \bufnum, Pseq(newvals, 1)).play;

				// wait, think
				pause = (((newvals-target).sum.abs / initSum)*10).linexp(0, 10, 10, 0.1, -3);
				pause.yield;
			}

		});

	);

	(
		// begin
		Pdef(\aPlaceToSpeak).play;
		~repeater.play;
		r.reset;
		r.play;
	);

}