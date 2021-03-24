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

/*Server.killAll*/

s.waitForBoot {
	//setup
	(
		~vdelbus = Bus.audio(s);

		TempoClock.default.tempo = 2;    // 2 beats/sec, or 120 BPM

		//load samples
		z = PathName.new(thisProcess.nowExecutingPath.dirname++"/phonemes/");
		~phon = Array.fill(z.files.size, {arg i; [z.files[i].fileNameWithoutExtension, Buffer.read(s, z.pathOnly+/+z.files[i].fileName)]});

		y = PathName.new(thisProcess.nowExecutingPath.dirname++"/samps/");
		~amb = Array.fill(y.files.size, {arg i; [y.files[i].fileNameWithoutExtension, Buffer.read(s, y.pathOnly+/+y.files[i].fileName)]});

		~ambbufs = ~amb.collect({ arg item;
			item[1].bufnum;
		});

		~phonbufs = ~phon.collect({ arg item;
			item[1].bufnum;
		});

		~getBufForLetter = {|letter|
			~phon.detect({ arg item; item[0]==letter })[1].bufnum
		};

		~getBufsForPhrase = {|phrase|
			phrase.collect({|item,i| ~getBufForLetter.value(item)})
		};

		~restTimes = [Rest(1),Rest(5),Rest(10),Rest(20),Rest(30)];
		~r = 5;
		~lastAmbLength;
	);

	(
		SynthDef.new(\samp, {|bufnum = 0, amp = 0.8, speed = 1, dur = 1, out = 0, bufstart = 10|
			var sig = PlayBuf.ar(1, bufnum, Lag3.kr(speed, dur/2), startPos: bufstart, doneAction: Done.freeSelf);
			sig = LPF.ar(sig, 14000, 1, 0);
			Out.ar(out, (sig*amp));
		}).add;

		SynthDef.new(\delLine, {|delaytime = 5, delayfactor = 0.5, win = 0.9, out, in|
			var sig = SwitchDelay.ar(
				in: In.ar(in),
				drylevel: 0,
				wetlevel: 0.8,
				delaytime: delaytime,
				delayfactor: delayfactor,
				maxdelaytime: 20.0
			);
			// sig = GrainIn.ar(1, Impulse.kr(32), 1, sig, 0, -1, 512, 0.1, 0);
			sig = PitchShift.ar(in: sig, windowSize: win, pitchRatio: 1, pitchDispersion: 0.001, timeDispersion: 0.001, mul: 1, add: 0);
			sig = LPF.ar(sig, rrand(440,15000), 1, 0);
			Out.ar(out, sig);
		}).add;



		SynthDef.new(\ambPlayer, {|bufnum, amp, speed, position, win, out, dur, overlaps = 8, rand = 0.2|
			var sig = Warp1.ar(numChannels: 2, bufnum: bufnum, pointer: Lag3.kr(position, dur/3), freqScale: Lag3.kr(speed, dur/2), windowSize: Lag3.kr(win, dur/3), envbufnum: -1, overlaps: Lag3.kr(overlaps,dur/5), windowRandRatio: Lag3.kr(rand,dur/5), interp: 2, mul: 1, add: 0);

			Out.ar(out, sig*Lag3.kr(amp, dur/5));
		}).add;
	);


	(

		Pdef(\hello, Pbind(*[
			instrument: \samp,
			bufnum: Pseq(~getBufsForPhrase.value(["h","eh","l","l","oh"]), 1),
			speed: rrand(0.95,1.5),
			amp: 0.8,
			roomsize: 1,
			out: 1,
			dur: Pseq([0.1,0.1,0.1,0.1,1.5, 0.1,0.1,0.1,0.1,0.1]),
		]));

		Pdef(\home, Pbind(*[
			instrument: \samp,
			bufnum: Pseq(~getBufsForPhrase.value(["h","oh","m"]), 1),
			speed: rrand(0.95,1.5),
			amp: 0.8,
			roomsize: 1,
			out: 1,
			dur: Pseq([0.1,0.2,0.1]),
		]));

		Pdef(\randomPhons, Plazy({
			Pbind(*[
				instrument: \samp,
				bufnum: Pxrand(~phonbufs.scramble, 12),
				amp: 0.2,
				speed: Pwhite(0.8, 1.5, 12),
				roomsize: Pwhite(0.5, 5, 12),
				dur: 0.5,
				out: 0
				// out: [0, ~vdelbus]
			])
		}));

		// {Perlin3.ar(*{Line.ar(0, 1000, 30)}.dup(3))}.plot(1);
	);


	(

		~voiceSeq = Pseq([Pwrand([Pdef(\randomPhons), Pdef(\hello)], [0.95,0.05],1), Pfuncn({~restTimes.choose})], inf).play;

		~voiceDel = Pmono(\delLine, *[
			delaytime: 0.01,
			delayfactor: Pxrand([0, 0.2, 0.1, 0.5], inf),
			dur: Pxrand([0.1, 0.5, 1, 0.25], inf),
			win: Pwhite(0.2, 2, inf),
			in: ~vdelbus.index,
			out: 1
		]).play;

		~ambSeq = Pseq([
			Plazy({
				// var length = [2, 5, 10, 15].choose;
				Pmono(\ambPlayer,
					\bufnum, Pxrand(~ambbufs, inf),
					\amp, Pseq([Pwhite(0.4, 0.8, 5), 0], inf),
					\speed, Pwhite(0.01, 5.0, inf),
					\position, Pwhite(0, 1.0, inf),
					\win, Plprand(0.05, 10, inf),
					\dur, Pseq([Pwhite(0.5, 15.0, 5), Pwhite(10,20,1)], inf),
					\rand, Plprand(0.1, 1, inf),
					\overlaps, Pwhite(2, 16, inf),
					\out, 0//2
				)
		})], inf).play;
	);


	(

		~dlt = 1;

		~target_r = Routine.new({
			loop {
				~getBufsForPhrase.value(["h","eh","l","oh"]).yield;
				~getBufsForPhrase.value(["y","eh","s"]).yield;
			}
		});

		//TODO: add variable/scale to delta related to the different from target

		r = Routine.new({|inval|
			var target = List.newUsing(~target_r.next);
			var newvals = List.fill(target.size, { rand(~phonbufs.size) });
			var i = 0;

			loop {
				var dlt = ~dlt;

				if(target == newvals, {
					i = i+1;

					if(i == 4, {
						i = 0;
						target = List.newUsing(~target_r.next);
						["next target:", target].postln;

						if(target.size > newvals.size, {
							(target.size - newvals.size).do({
								newvals.add(rand(~phonbufs.size));
							});
						});
						if(target.size < newvals.size, { newvals = newvals.copyRange(0,target.size-1) });

					});
				});

				["newvals:",newvals, "i:", i].postln;

				target.do({ |item, j|
					var v = newvals[j];

					case
					{v == item} {v = v}
					{v > item} {v = v-dlt}
					{v < item} {v = v+dlt};

					newvals.put(j,v);

					Synth(\samp, [\bufnum, ~phonbufs[v]]);

					0.3.wait;
				});

				rrand(0.5,5).yield;
			}

		});

		r.play;

		r.reset;
		r.stop;

	)

	// RECORD TO MULTICHANNEL FILE
	// Server.default.record(numChannels: 10);
	Server.default.record(numChannels: 2);
	Server.default.stopRecording;

}