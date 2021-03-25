(
// s.options.outDevice = "MOTU UltraLite mk3 Hybrid";
// s.options.inDevice = "MOTU UltraLite mk3 Hybrid";

// s.options.outDevice = "Universal Audio Thunderbolt";
// s.options.inDevice = "Universal Audio Thunderbolt";

// s.options.outDevice = "MOTU Audio ASIO";
// s.options.inDevice = "MOTU Audio ASIO";

s.options.numOutputBusChannels = 4;

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
			Out.ar([out,~vdelbus.index], sig*amp);
		}).add;

		SynthDef.new(\delLine, {|delaytime = 5, delayfactor = 0.5, win = 0.9, out, in|
			var sig = SwitchDelay.ar(
				in: In.ar(in),
				drylevel: 0,
				wetlevel: 0.7,
				delaytime: delaytime,
				delayfactor: delayfactor,
				maxdelaytime: 20.0
			);
			// sig = GrainIn.ar(1, Impulse.kr(32), 1, sig, 0, -1, 512, 0.1, 0);
			sig = PitchShift.ar(in: sig, windowSize: win, pitchRatio: 1, pitchDispersion: 0.5, timeDispersion: 0.001, mul: 1, add: 0);
			// sig = LPF.ar(sig, rrand(440,15000), 1, 0);
			Out.ar(out, sig);
		}).add;

		SynthDef.new(\amb, {|bufnum, amp, speed, position, win, out, dur, overlaps = 8, rand = 0.2|
			var sig = Warp1.ar(numChannels: 2, bufnum: bufnum, pointer: Lag3.kr(position, dur/3), freqScale: Lag3.kr(speed, dur/2), windowSize: Lag3.kr(win, dur/3), envbufnum: -1, overlaps: Lag3.kr(overlaps,dur/5), windowRandRatio: Lag3.kr(rand,dur/5), interp: 2, mul: Lag3.kr(amp, dur/5), add: 0);

			Out.ar(out, sig*0.8);
		}).add;


		SynthDef.new(\tone, {|freq, out, amp = 0.8, gate = 1, dur|
			var sig;
			var env = Env.asr(0.5, 1, 2, -4.0);
			sig = DynKlang.ar(`[ freq, [0.33,0.33,0.33] ], 1, 0);
			sig = Mix.new([sig, HPF.ar(WhiteNoise.ar(0.02), 15000, 1)]);
			sig = Pan2.ar(sig, FSinOsc.kr(0.25), 1)*EnvGen.kr(env, gate, doneAction: Done.freeSelf);
			Out.ar(out, sig*amp)
		}).add;
	);

	s.sync();

	(
		Pdef(\ppBase,
			Pbind(\instrument, \phonsynth,
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

		Pdef(\tonePlay, Pbind(\instrument, \tone, \dur, Pwhite(0.5,10,3), \legato, 1.05, \root, -12, \degree, Ptuple([Pxrand((0..12), 3), Pxrand((0..12), 3), Pxrand((0..12), 3)]), \scale, Scale.new(#[ 0, 1, 3, 5, 7, 8, 10 ], 13)));

		Pdef(\ambMono, Pseq([
			Plazy({
				var length = [2, 5, 10, 15].choose;
				Pmono(\amb,
					\bufnum, Pxrand(~ambbufs, length),
					\amp, Pseq([Pwhite(0.2, 0.3, length), 0], length),
					\speed, Pwhite(0.01, 3.0, length),
					\position, Pwhite(0, 1.0, length),
					\win, Plprand(0.05, 10, length),
					\dur, Pwhite(1, 15.0,length),
					\rand, Plprand(0.1, 1, length),
					\overlaps, Pwhite(2, 16, length),
					\legato, 1.05,
					\out, 2
				)
		}), Pseq([Rest(10)], 1)], inf));

		Pdef(\ambPlayer, Pdef(\ambMono));

		Pdef(\ambPlayer).fadeTime = 1;
	);

	(

		~target_r = Pxrand([
			~getBufsForPhrase.value(["h","eh","l","oh"]),
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
			~getBufsForPhrase.value(["n","au","th","ee","ng","n","eh","s"])
		], inf);

		r = Routine.new({|inval|
			var ts = ~target_r.asStream;
			var target = List.newUsing(ts.next);
			var newvals = List.fill(target.size, { rand(~phonbufs.size) });
			var i = 0;
			var dlt = 1;
			var pause = 1; //init placeholder pause
			var initSum = (newvals-target).sum.abs;

			// 30.wait;

			loop {

				if(target == newvals, {
					i = i+1;
					pause = 1;

					Pdef(\ambPlayer, Pdef(\tonePlay));

					if(i == 4, {
						i = 0;
						target = List.newUsing(ts.next);
						3.wait;
						// ["next target:", target].postln;

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

						((30.rand)+10).wait;

						Pdef(\ambPlayer, Pdef(\ambMono));

						((30.rand)+5).wait;

					});
				});

				// ["target: ", target, "newvals:", newvals, "i:", i].postln;

				target.do({ |item, j|
					var v = newvals[j];
					var ldlt = dlt;

					case
					{v == item} {v = v}
					{v > item} {v = v-dlt}
					{v < item} {v = v+dlt};

					newvals.put(j,v);
				});

				Pdef(\pp, Pbind(\bufnum, Pseq(newvals, 1), \amp, 0.7) <> Pdef(\ppBase));

				//determine pause with velocity
				pause = ((newvals-target).sum.abs / initSum).lincurve(0, 1, 7, 0.1, -3);
				// pause.postln;

				pause.yield;
			}

		});

	);

	(
		//start everything
		Pdef(\ambPlayer).play;
		Pdef(\pp).play;
		~voiceDelPlayer = ~voiceDel.play;
		r.reset;
		r.play;
	);

}

// RECORD TO MULTICHANNEL FILE
// Server.default.record(numChannels: 2);
// Server.default.stopRecording;