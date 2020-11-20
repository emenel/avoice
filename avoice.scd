(
s.options.outDevice = "MOTU UltraLite mk3 Hybrid";
s.options.inDevice = "MOTU UltraLite mk3 Hybrid";

s.options.outDevice = "Universal Audio Thunderbolt";
s.options.inDevice = "Universal Audio Thunderbolt";

s.options.numOutputBusChannels = 10;

s.options.sampleRate = 44100;
s.boot;
);

/*Server.killAll*/

s.waitForBoot {
	//setup
	(
		~sources = Group.new;
		~vdelbus = Bus.audio(s);

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


		~restTimes = [Rest(5),Rest(10),Rest(20),Rest(30)];

		~r = 5;
	);

	(
		SynthDef.new(\samp, {|bufnum, amp, speed, roomsize|
			var out = [0, ~vdelbus];
			var sig = PlayBuf.ar(1, bufnum, speed, startPos: 10, doneAction: Done.freeSelf);
			sig = FreeVerb.ar(sig, mix: 0.33, room: 0, damp: 0, mul: 1.0, add: 0.0);
			sig = LPF.ar(sig, 14000, 1, 0);
			Out.ar(out, (sig*amp));
		}).add;

		SynthDef.new(\delLine, {|delaytime = 5, delayfactor = 0.5, out, in|
			var del = SwitchDelay.ar(
				in: In.ar(in),
				drylevel: 0,
				wetlevel: 0.9,
				delaytime: delaytime,
				delayfactor: delayfactor,
				maxdelaytime: 20.0
			);

			del = LPF.ar(del, rrand(440,15000), 1, 0);
			// var del = TGrains.ar(1, Dust.ar(100,1,0), in, 1, delayfactor/8, 0.1, 0, 0.1, 4);

			Out.ar(out, del);
		}).add;

		SynthDef.new(\ambPlayer, {|bufnum, amp, speed, position, win, out, dur|
			var sig = Warp1.ar(numChannels: 2, bufnum: bufnum, pointer: Lag3.kr(position, dur/3), freqScale: Lag3.kr(speed, dur/2), windowSize: Lag3.kr(win, dur/3), envbufnum: -1, overlaps: 8, windowRandRatio: 0.2, interp: 2, mul: 1, add: 0);
			Out.ar(out, sig*Lag3.kr(amp, dur/2));
		}).add;

		SynthDef.new(\toneOp, {|freq, out, amp, gate = 1|
			// var sig = Blip.ar(freq, 5, 0.1, 0);
			var sig;
			// sig = SinOsc.ar(freq,0,1,0);
			var env = Env.asr(0.5, 1, 2, -4.0);
			sig = DynKlang.ar(`[ [freq, freq*2, freq*1.2, freq*0.5, freq*1], [0.2,0.2,0.2,0.2,0.2] ], 1, 0);
			sig = Pan2.ar(sig, FSinOsc.kr(1), 1)*EnvGen.kr(env, gate, doneAction: Done.freeSelf);
			Out.ar(out, sig*amp)
		}).add;
	);


	(

		/*var baseEvent;

		baseEvent = (
			dur: 1.0,
			freq: 440,
			amp: 0.1
		);

		Pbindf(Pfuncn({ baseEvent }, inf), *[
			instrument: \pad,
			filterfreq: Pexprand(1000, 8000, inf)
		]).play;
		*/


		Pdef(\move, Pbind(*[
			instrument: \samp,
			addAction: ~sources,
			speed: 0.9,
			roomsize: 1,
			bufnum: Pseq(~getBufsForPhrase.value(["m","oo", "v", "f", "oh", "w", "ar", "r", "d"]), 1),
			amp: Pseq([0.4,0.4,0.2, 0.4,0.2,0.4,0.4,0.3,0.1]),
			dur: Pseq([0.2,0.2,1, 0.2,0.2,0.2,0.3,0.2,0.2]),
		]));

		Pdef(\reason, Pbind(*[
			instrument: \samp,
			addAction: ~sources,
			bufnum: Pseq(~getBufsForPhrase.value(["th","ee", "oh","n","l","ee", "r","ee","s","uh","n"]), 1),
			speed: 0.9,
			amp: 0.9,
			roomsize: 1,
			dur: Pseq([0.2,1, 0.2,0.3,0.2,1, 0.2,0.3,0.2,0.2,1]),
		]));

		Pdef(\exist, Pbind(*[
			instrument: \samp,
			addAction: ~sources,
			bufnum: Pseq(~getBufsForPhrase.value(["w","ee", "n","oh", "w","ee", "eh","k","z","ih","s","t"]), 1),
			speed: 0.9,
			amp: 0.9,
			roomsize: 1,
			dur: Pseq([0.1,1, 0.1,1, 0.1,1, 0.2,0.1,0.2,0.2,0.2,1]),
		]));

		Pdef(\hello, Pbind(*[
			instrument: \samp,
			addAction: ~sources,
			bufnum: Pseq(~getBufsForPhrase.value(["h","eh","l","l","oh", "w","eau","r","l","d"]), 1),
			speed: 0.9,
			amp: 0.9,
			roomsize: 1,
			dur: Pseq([0.1,0.1,0.1,0.1,1, 0.1,1,0.1,0.1,0.1,0.1,0.1]),
		])).play;

		Pdef(\randomPhons, Plazy({
			var length = [10, 15, 20, 30].wchoose([0.1,0.3,0.4,0.2]);
			Pbind(*[
				instrument: \samp,
				addAction: ~sources,
				bufnum: Pxrand(~phonbufs.scramble, length),
				amp: rrand(0.2,0.4),
				speed: Pwhite(0.8, 1.1, length),
				roomsize: Pwhite(0.5, 5, length),
				dur: Pwhite(0.01, 0.1, length),
			])
		})).play;

	);


	(
		~voiceSeq = Pseq([Pwrand([Pdef(\randomPhons), Pdef(\hello), Pdef(\move), Pdef(\reason), Pdef(\exist)], [0.9, 0.025, 0.025, 0.025, 0.025], 1), Pfuncn({~restTimes.choose})], inf).play;

		~voiceDel = Pmono(\delLine, *[
			delaytime: 4,
			delayfactor: Pxrand([0, 0.2, 0.1, 0.5], inf),
			dur: Pxrand([0.1, 0.5, 1, 0.25], inf),
			in: ~vdelbus.index,
			out: 1
		]).play;

		~ambSeq = Pseq([
			Plazy({
				var length = [5, 10].choose;
				Pmono(\ambPlayer,
					\bufnum, Pxrand(~ambbufs, length),
					\amp, Pwhite(0.1, 0.5, length),
					\speed, Pwhite(0.01, 5.0, length),
					\position, Pwhite(0, 1.0, length),
					\win, Pwhite(0.05, 10, length),
					\dur, Pwhite(0.5, 15.0, length),
					\phrasel, length,
					\out, 0//4
				)
			}).collect({|event|
				~lastAmbLength = event;
			}),
			(Rest(~lastAmbLength.phrasel)*rrand(2,3)).postln
		], inf).play;

		/*~toneSeq = Pseq([
			Plazy({
				var length = [5, 10, 15].wchoose([0.4,0.4,0.2]);

				Pmono(\toneOp,
					\freq, Pwhite(340,350, length),
					\amp, Pwhite(0.05, 0.2, length),
					\dur, Pwhite(1.0, 2.0, length),
					\out, 2
				)
			}),
			~restTimes.choose+(30.rand+20)
		], inf).play;*/

	);

	// RECORD TO MULTICHANNEL FILE
	// Server.default.record(numChannels: 10);
	Server.default.record(numChannels: 2);
	Server.default.stopRecording;

}