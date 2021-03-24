(
// s.options.outDevice = "MOTU UltraLite mk3 Hybrid";
// s.options.inDevice = "MOTU UltraLite mk3 Hybrid";

// s.options.outDevice = "Universal Audio Thunderbolt";
// s.options.inDevice = "Universal Audio Thunderbolt";

// s.options.outDevice = "MOTU Audio ASIO";
// s.options.inDevice = "MOTU Audio ASIO";

s.options.numOutputBusChannels = 2;

s.options.sampleRate = 44100;
s.boot;
);

s.waitForBoot {
	//setup
	(
		~vdelbus = Bus.audio(s);

		TempoClock.default.tempo = 1;    // 2 beats/sec, or 120 BPM

		//load samples
		z = PathName.new(thisProcess.nowExecutingPath.dirname++"/phonemes/");
		~phonsamps = Array.fill(z.files.size, {arg i; [z.files[i].fileNameWithoutExtension, Buffer.read(s, z.pathOnly+/+z.files[i].fileName)]});

		y = PathName.new(thisProcess.nowExecutingPath.dirname++"/samps/");
		~ambsamps = Array.fill(y.files.size, {arg i; [y.files[i].fileNameWithoutExtension, Buffer.read(s, y.pathOnly+/+y.files[i].fileName)]});

		~ambbufs = ~ambsamps.collect({ arg item;
			item[1].bufnum;
		});

		~phonbufs = ~phonsamps.collect({ arg item;
			item[1].bufnum;
		});

		~getBufForLetter = {|letter|
			~phonsamps.detect({ arg item; item[0]==letter })[1].bufnum
		};

		~getBufsForPhrase = {|phrase|
			phrase.collect({|item,i| ~getBufForLetter.value(item)})
		};

		~restTimes = [Rest(1),Rest(5),Rest(10),Rest(20),Rest(30)];
		~r = 5;
		~lastAmbLength;
	);

	(
		SynthDef.new(\phonsynth, {|bufnum = 0, amp = 0, speed = 1, dur = 1, out = 0, bufstart = 10|
			var sig = PlayBuf.ar(1, bufnum, Lag3.kr(speed, dur/2), startPos: bufstart, doneAction: Done.freeSelf);
			// sig = LPF.ar(sig, 17000, 1, 0);
			Out.ar([0,~vdelbus.index], sig*amp);
		}).add;

		SynthDef.new(\delLine, {|delaytime = 5, delayfactor = 0.5, win = 0.9, out, in|
			var sig = SwitchDelay.ar(
				in: In.ar(in),
				drylevel: 0,
				wetlevel: 1,
				delaytime: delaytime,
				delayfactor: delayfactor,
				maxdelaytime: 20.0
			);
			// sig = GrainIn.ar(1, Impulse.kr(32), 1, sig, 0, -1, 512, 0.1, 0);
			sig = PitchShift.ar(in: sig, windowSize: win, pitchRatio: 1, pitchDispersion: 0.5, timeDispersion: 0.001, mul: 1, add: 0);
			// sig = LPF.ar(sig, rrand(440,15000), 1, 0);
			Out.ar(1, sig);
		}).add;

		SynthDef.new(\amb, {|bufnum, amp, speed, position, win, out, dur, overlaps = 8, rand = 0.2|
			var sig = Warp1.ar(numChannels: 2, bufnum: bufnum, pointer: Lag3.kr(position, dur/3), freqScale: Lag3.kr(speed, dur/2), windowSize: Lag3.kr(win, dur/3), envbufnum: -1, overlaps: Lag3.kr(overlaps,dur/5), windowRandRatio: Lag3.kr(rand,dur/5), interp: 2, mul: Lag3.kr(amp, dur/5), add: 0);

			Out.ar(out, sig);
		}).add;
	);

	(
		Pdef(\ppBase,
			Pbind(\instrument, \phonsynth,
				// \bufnum, Pseq(~getBufsForPhrase.value(["h","eh","l","oh"]), inf),
				\dur, Pfunc({|d| (s.cachedBufferAt(d.bufnum).duration)-0.1}),
				\speed, Pwhite(0.9,1.1,inf),
				\legato, 1.1
			)
		);

		Pdef(\pp, Pbind(\bufnum, Pseq(~getBufsForPhrase.value(["h","eh","l","oh"]), 1), \amp, 0) <> Pdef(\ppBase));

		Pdef(\ppBase).fadeTime = 1;
		Pdef(\pp).fadeTime = 1;

		~voiceDel = Pmono(\delLine, *[
			delaytime: 0.01,
			delayfactor: Pxrand([0, 0.2, 0.1, 0.5], inf),
			dur: Pxrand([0.1, 0.5, 1, 0.25], inf),
			win: Pwhite(0.2, 2, inf),
			in: ~vdelbus.index,
			out: 1
		]);

		~ambSeq = Pseq([
			Plazy({
				var length = [2, 5, 10, 15].choose;
				Pmono(\amb,
					\bufnum, Pxrand(~ambbufs, length),
					\amp, Pseq([Pwhite(0.2, 0.8, length), 0], length),
					\speed, Pwhite(0.01, 5.0, length),
					\position, Pwhite(0, 1.0, length),
					\win, Plprand(0.05, 10, length),
					\dur, Pseq([Pwhite(0.5, 15.0, 5), Pwhite(10,20,1)], length),
					\rand, Plprand(0.1, 1, length),
					\overlaps, Pwhite(2, 16, length),
					\legato, 1.05,
					\out, 0//2
				)
		}), Prand((10..30)).collect(Rest(_))], inf);

	);

	(

		~target_r = Pxrand([
			~getBufsForPhrase.value(["h","eh","l","oh"]),
			~getBufsForPhrase.value(["i"]),
			~getBufsForPhrase.value(["a", "m"]),
			~getBufsForPhrase.value(["s","p","ee","k","ee","ng"]),
			~getBufsForPhrase.value(["d", "aw", "n"]),
			~getBufsForPhrase.value(["d","r","ee","m"]),
			~getBufsForPhrase.value(["h","aw","l","t","d"]),
			~getBufsForPhrase.value(["t","i","m"]),
			~getBufsForPhrase.value(["s","p","oh","k","eh","n"]),
			~getBufsForPhrase.value(["y","oo","n","ih","t","ee","s"]),
			~getBufsForPhrase.value(["m","oh","m","eh","n","t"]),
			~getBufsForPhrase.value(["eh","n","ch","a","n","t"]),
			~getBufsForPhrase.value(["j","oi"]),
			~getBufsForPhrase.value(["b","a","k","g","r","ow","n","d"]),
			~getBufsForPhrase.value(["r","eh","p","eh","t","ih","sh","ih","n"]),
			~getBufsForPhrase.value(["s","t","ai","s","ih","s"]),
			~getBufsForPhrase.value(["s","p","i","r","a","l"]),
			~getBufsForPhrase.value(["t","r","a","n","s","f","oh","r","m"]),
		], inf);

		r = Routine.new({|inval|
			var ts = ~target_r.asStream;
			var target = List.newUsing(ts.next);
			var newvals = List.fill(target.size, { rand(~phonbufs.size) });
			var i = 0;
			var dlt = 1;
			var pause = 1; //init placeholder pause
			var initSum = (newvals-target).sum.abs;

			30.wait;

			loop {

				if(target == newvals, {
					i = i+1;
					pause = 1;

					if(i == 4, {
						i = 0;
						target = List.newUsing(ts.next);
						3.wait;
						["next target:", target].postln;

						if(target.size > newvals.size, {
							(target.size - newvals.size).do({
								newvals.add(rand(~phonbufs.size));
							});
						});
						if(target.size < newvals.size, { newvals = newvals.copyRange(0,target.size-1) });

						if(newvals == target, {
							initSum = 1;
						}, {
							initSum = (newvals-target).sum.abs;
						});

						rrand(15,25).wait;
					});
				});

				["target: ", target, "newvals:", newvals, "i:", i].postln;

				target.do({ |item, j|
					var v = newvals[j];
					var ldlt = dlt;

					case
					{v == item} {v = v}
					{v > item} {v = v-dlt}
					{v < item} {v = v+dlt};

					newvals.put(j,v);

					// Pdef(\pp, Pbind(\instrument, \phonsynth, \dur, 0.3, \bufnum, Pseq([~phonbufs[v]], 1)));

					// Synth(\phonsynth, [\bufnum, ~phonbufs[v]]);
					// 0.25.wait;
				});

				Pdef(\pp, Pbind(\bufnum, Pseq(newvals, 1), \amp, 0.7) <> Pdef(\ppBase));

				//determine pause with velocity
				pause = ((newvals-target).sum.abs / initSum).lincurve(0, 1, 7, 0.1, -3);
				pause.postln;

				pause.yield;
			}

		});

	);

	(

		//start everything
		~ambSeq.play;

		Pdef(\pp).play;
		~voiceDel.play;

		r.reset;
		r.play;

	);

}

// RECORD TO MULTICHANNEL FILE
// Server.default.record(numChannels: 2);
// Server.default.stopRecording;