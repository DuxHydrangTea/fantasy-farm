"""Rebuild P2 audio: Python + numpy + ffmpeg; public CC0 recordings and original scores."""
from pathlib import Path
from urllib.request import urlopen
import tempfile,subprocess,json,hashlib,wave,re,sys
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/sound/p2'; OUT.mkdir(parents=True,exist_ok=True)
CACHE=Path(tempfile.gettempdir())/'fantasy-farm-p2-sources'; CACHE.mkdir(exist_ok=True)
ROWS=[]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def encode(name,x,source,peak,processing):
    x-=np.mean(x); x*=10**(peak/20)/np.max(abs(x))
    wav=CACHE/(name+'.wav')
    with wave.open(str(wav),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(44100);w.writeframes((x*32767).astype('<i2').tobytes())
    dest=OUT/(name+'.ogg')
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(wav),'-c:a','libvorbis','-q:a','4',str(dest)],check=True)
    ROWS.append({'event':name,'file':dest.relative_to(ROOT).as_posix(),'duration':len(x)/44100,'peak_db':peak,'loop':True,'source':source,'processing':processing,'sha256':sha(dest)})
for name,page,start,seconds,cutoff,peak in [('birds_day','countryside-s0097.html',12,25,3800,-24),('crickets_night','song-of-nocturnal-insect-2-s0425.html',1,12,2400,-29),('rain_loop','rain-on-puddle-s1290.html',15,25,3200,-24)]:
    if '--only-crickets' in sys.argv and name!='crickets_night':continue
    url='https://bigsoundbank.com/'+page; src=CACHE/(name+'.mp3'); meta=CACHE/(name+'.json')
    # Reuse previously downloaded source names when available.
    alias={'birds_day':'birds','crickets_night':'crickets'}.get(name,name)
    existing=CACHE/(alias+'.mp3')
    if existing.exists():src=existing
    if not src.exists():
        html=urlopen(url,timeout=40).read().decode();assert 'CC0' in html
        download='https://bigsoundbank.com'+re.findall(r'/UPLOAD/mp3/\d+\.mp3',html)[0]
        src.write_bytes(urlopen(download,timeout=60).read())
    filters=f'highpass=f=100,'+','.join([f'lowpass=f={cutoff}']*(4 if name=='crickets_night' else 2))
    data=subprocess.check_output(['ffmpeg','-v','error','-ss',str(start),'-i',str(src),'-t',str(seconds),'-af',filters,'-f','f32le','-ac','1','-ar','44100','pipe:1'])
    x=np.frombuffer(data,dtype='<f4').copy(); n=44100
    # Wrap tail into head, preserving a continuous noise bed at the seam.
    mix=np.linspace(0,1,n);x[:n]=x[-n:]*(1-mix)+x[:n]*mix;x=x[:-n]
    # Exact sample continuity after the crossfade.
    x[-882:]+=np.linspace(0,float(x[0]-x[-1]),882)
    encode(name,x,{'author':'Joseph SARDIN','license':'CC0-1.0','url':url,'source_sha256':sha(src)},peak,f'{start}s excerpt, highpass100, {4 if name=="crickets_night" else 2} lowpass filters at {cutoff}Hz, 1s wrap crossfade, peak normalize')

# Original 16-bar scores: no samples, square waves, percussion or borrowed melody.
chords=['C3+E3+G3','G2+B2+D3','A2+C3+E3','F2+A2+C3','C3+E3+G3','E3+G3+B3','F2+A2+C3','G2+B2+D3']*2
melodies={
 'day':('E4 G4 A4 G4 E4 D4 G4 . E4 C4 E4 A4 G4 E4 D4 . F4 A4 G4 E4 C4 E4 G4 . A4 G4 E4 D4 C4 D4 E4 .'.split(),76),
 'twilight':('G4 E4 D4 . E4 G4 E4 . C4 E4 G4 . A4 G4 E4 . F4 E4 C4 . E4 D4 B3 . C4 D4 E4 . D4 B3 G3 .'.split(),66),
 'night':('E4 . C4 . B3 . G3 . A3 . C4 . E4 . D4 . C4 . A3 . G3 . B3 . C4 . E4 . D4 . G3 .'.split(),58)}
for phase,(melody,tempo) in melodies.items():
    if '--only-crickets' in sys.argv:continue
    song={'name':'farm_'+phase,'tempo':tempo,'steps_per_beat':2,'beats_per_bar':4,'bars':16,'sample_rate':44100,'master_volume':1.0,'tracks':[
     {'name':'warm_pad','wave':'sine','volume':.22,'envelope':{'attack':.32,'decay':.5,'sustain_level':.65,'release':.6},'notes':[{'note':c,'len':8} for c in chords]},
     {'name':'soft_keys','wave':'sine','volume':.28,'envelope':{'attack':.045,'decay':.45,'sustain_level':.12,'release':.5},'notes':[{'note':n,'len':4} for n in melody]},
     {'name':'bass','wave':'sine','volume':.12,'envelope':{'attack':.12,'decay':.4,'sustain_level':.5,'release':.5},'notes':[{'note':c.split('+')[0],'len':8} for c in chords]}]}
    score=OUT/('music_'+phase+'.json');score.write_text(json.dumps(song,indent=2))
    wav=CACHE/('music_'+phase+'.wav')
    cmd=[sys.executable,str(ROOT/'.agents/skills/godot/scripts/assets/make_music.py'),'--song',str(score),'--out',str(wav),'--peak-db','-20']
    result=subprocess.run(cmd,capture_output=True,text=True);assert result.returncode==0,result.stderr
    data=subprocess.check_output(['ffmpeg','-v','error','-i',str(wav),'-f','f32le','-ac','1','-ar','44100','pipe:1']);x=np.frombuffer(data,dtype='<f4').copy()
    encode('music_'+phase,x,{'author':'Fantasy Farm project','license':'Original project asset; no third-party samples','type':'original procedural composition','score':score.relative_to(ROOT).as_posix(),'renderer':'.agents/skills/godot/scripts/assets/make_music.py'},-20,'Original 16 bars, sine pad/keys/bass, no percussion; renderer wraps release tails at loop seam')
if '--only-crickets' in sys.argv:
    updates={r['event']:r for r in ROWS}
    ROWS=[updates.get(r['event'],r) for r in json.loads((OUT/'manifest.json').read_text())['events']]
(OUT/'manifest.json').write_text(json.dumps({'version':1,'events':ROWS,'existing_wind':'res://assets/audio/farm_wind.wav (WeatherEffects owns the only wind voice)'},indent=2))
(OUT/'README.md').write_text('# P2 farm atmosphere\n\nDay birds, night crickets, rain and three original quiet music loops. WeatherEffects retains the existing wind loop so wind is never doubled. Environment uses Ambience; scores use the independent Music bus.\n\nRecordings: Joseph SARDIN / BigSoundBank, CC0-1.0. Exact source URLs, source/output hashes, processing and peak levels: manifest.json. Original scores and rendered music are project assets with no third-party samples. License: https://creativecommons.org/publicdomain/zero/1.0/legalcode\n\nRebuild: `py scripts/audio/build_p2_audio.py` (numpy, ffmpeg, bundled Godot skill renderer). Cached public recordings live in the OS temporary folder.\n\nRuntime: 3s environment fade, 5s music crossfade; the same farm timeline and debug hour as lighting. Rain reduces wildlife to 20%; wind reduces it to 55%. Music defaults to 45% and is further reduced during rain. Players belong to the world and pause/free with it.\n')
(OUT/'review.html').write_text('<meta charset="utf-8"><title>P2 audio</title><style>body{font:16px sans-serif;background:#202723;color:#eee;max-width:720px;margin:35px auto}article{padding:12px;border-bottom:1px solid #777}</style><h1>P2 farm atmosphere</h1><p>Clips play here at asset volume. In game they are mixed lower, with independent Music and Ambience controls.</p>'+''.join(f'<article><p>{r["event"]} Ã‚Â· {r["duration"]:.1f}s</p><audio controls src="{Path(r["file"]).name}"></audio></article>' for r in ROWS))
(ROOT/'components/p2_sound_catalog.gd').write_text('extends RefCounted\n## Provenance and original scores: assets/sound/p2/manifest.json.\nconst LOOPS: Dictionary = {\n'+''.join(f'\t&"{r["event"]}": preload("res://{r["file"]}"),\n' for r in ROWS)+'}\n')
print('Built',len(ROWS),'P2 loops')
