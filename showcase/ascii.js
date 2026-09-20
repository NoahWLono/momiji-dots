/* Procedural ASCII art. Every visible mark in the artwork is a printable ASCII glyph. */
const MomijiArt = (() => {
  const W=640,H=180,BG='#0d1110';
  const P={ink:'#eee9d9',muted:'#b1b5a6',gold:'#D4A017',light:'#f6d989',auburn:'#9A3F24',copper:'#d28c61',green:'#4F7A3A',leaf:'#a1c37a',dim:'#26372a',steel:'#93a69b'};
  const g=Array.from({length:H},()=>Array(W).fill(' '));
  const c=Array.from({length:H},()=>Array(W).fill(P.ink));
  function put(x,y,s,col=P.ink){if(y<0||y>=H)return; [...s].forEach((a,i)=>{if(x+i>=0&&x+i<W){g[y][x+i]=a.charCodeAt(0)>=32&&a.charCodeAt(0)<127?a:'?';c[y][x+i]=col;}});}
  function line(x1,y1,x2,y2,ch='.',col=P.dim){let n=Math.max(Math.abs(x2-x1),Math.abs(y2-y1));for(let i=0;i<=n;i++){let t=n?i/n:0;put(Math.round(x1+(x2-x1)*t),Math.round(y1+(y2-y1)*t),ch,col);}}
  function rect(x,y,w,h,col=P.gold,fill=true){if(fill)for(let yy=y;yy<y+h;yy++)put(x,yy,' '.repeat(w));put(x,y,'+'+'-'.repeat(w-2)+'+',col);put(x,y+h-1,'+'+'-'.repeat(w-2)+'+',col);for(let yy=y+1;yy<y+h-1;yy++){put(x,yy,'|',col);put(x+w-1,yy,'|',col);}}
  function text(x,y,lines,col=P.ink,step=2){lines.forEach((a,i)=>put(x,y+i*step,a,col));}
  function titleBox(x,y,w,h,title,col=P.gold){rect(x,y,w,h,col);put(x+3,y,'[ '+title+' ]',col);}
  function poly(points,col=P.gold,chars='.:+*#'){let minx=Math.min(...points.map(p=>p[0])),maxx=Math.max(...points.map(p=>p[0])),miny=Math.min(...points.map(p=>p[1])),maxy=Math.max(...points.map(p=>p[1]));for(let y=miny;y<=maxy;y++)for(let x=minx;x<=maxx;x++){let inside=false;for(let i=0,j=points.length-1;i<points.length;j=i++){let [xi,yi]=points[i],[xj,yj]=points[j];if(((yi>y)!=(yj>y))&&(x<(xj-xi)*(y-yi)/(yj-yi)+xi))inside=!inside;}if(inside)put(x,y,chars[(x*7+y*11)%chars.length],col);}}
  function leaf(x,y,s=1,col=P.copper){let q=[[0,0],[-3,-3],[-14,-7],[-10,-8],[-15,-17],[-5,-13],[-5,-22],[0,-17],[5,-27],[9,-16],[16,-20],[13,-10],[24,-12],[17,-3],[20,0],[8,3],[2,9]];poly(q.map(([a,b])=>[Math.round(x+a*s),Math.round(y+b*s)]),col,'.:+*#');line(x,y-16*s,x+2*s,y+11*s,'|',P.light);}
  function banner(str,x,y,w,h,col=P.light){const t=document.createElement('canvas');t.width=w;t.height=h;let q=t.getContext('2d');q.font=`900 ${h}px monospace`;q.textBaseline='middle';q.scale(w/q.measureText(str).width,1);q.fillText(str,0,h*.49);let a=q.getImageData(0,0,w,h).data;for(let yy=0;yy<h;yy++)for(let xx=0;xx<w;xx++){let v=a[(yy*w+xx)*4+3];if(v>40)put(x+xx,y+yy,v>210?'#':v>120?'*':':',col);}}
  for(let yy=1;yy<H-1;yy+=4)for(let xx=2;xx<W-2;xx+=7)if((xx*13+yy*19)%17<4)put(xx,yy,'.',P.dim);
  rect(2,1,636,178,P.green,false);
  for(let k=0;k<12;k++){let y=29+k*10;line(4,y,14,y,'-',P.green);line(625,y,636,y,'-',P.green);}
  banner('MOMIJI',18,4,312,21,P.light);
  text(23,26,['H O S T N A M E : M O M I J I   /   T H E   A U T U M N   T E R M I N A L   S H R I N E'],P.gold,1);
  text(354,7,['MAPLE NEKOKAMI   /   SYSTEMS OF CARE','ARCH LINUX  //  HYPRLAND  //  CAELESTIA','HP 255 G10  |  OWNER-REPORTED RYZEN 3 7320U','16 GB RAM  /  512 GB SSD  /  ONE VERY LOVED LAPTOP','PROCEDURAL ASCII ILLUSTRATION  |  NO LIVE TELEMETRY','REPO SNAPSHOT: 307f6c5  /  2026-09-20'],P.ink,3);
  leaf(605,26,.6,P.copper);leaf(581,26,.35,P.green);
  line(16,31,624,31,'=',P.gold);
  titleBox(17,36,137,43,'01 / SILICON & INTENT');
  text(22,40,['MACHINE       HP 255 G10','CPU*          AMD Ryzen 3 7320U','CORES**       4 / 8 THREADS / ZEN 2','CLOCKS**      2.4 BASE / UP TO 4.1 GHz','TDP**         15 W DEFAULT (NOT WALL POWER)','GRAPHICS**    RADEON 610M','MEMORY*       16 GB','STORAGE*      512 GB SSD','DISTRO        ARCH LINUX','SHELL         FISH','TERMINAL      FOOT','COMPOSITOR    HYPRLAND','DESKTOP       CAELESTIA','CURSOR        MOMIJI-PAW / 32','* OWNER REPORT   ** AMD SPECIFICATION','EXACT PANEL / WIFI / BATTERY: UNVERIFIED'],P.ink,2);
  put(22,75,'MODE: CUTE, COMPETENT, NOT A BENCHMARK',P.leaf);
  titleBox(17,84,137,68,'02 / TRUST BOUNDARIES',P.green);
  const flows=[['UEFI / SYSTEMD-BOOT','1 GiB unencrypted EFI System Partition'],['LUKS2 DISK UNLOCK','root + home data inside encrypted container'],['BTRFS @ + @home','same encrypted boundary; separate subvolumes'],['SDDM USER LOGIN','password required; no autologin'],['HYPRLAND + CAELESTIA','user-owned Lua additions / familiar workspace']];
  flows.forEach(([a,b],i)=>{let y=88+i*10;rect(22,y,126,7,i%2?P.green:P.gold);put(26,y+2,a,P.light);put(26,y+4,b,P.ink);if(i<4)text(82,y+7,['|','v'],P.gold,1);});
  text(22,141,['ZRAM: ram / 2  |  ZSTD  |  NO DISK SWAP','NO HIBERNATION  /  WEEKLY FSTRIM DESIGN','TEMPLATES ARE PUBLIC. CREDENTIALS ARE NOT.'],P.leaf,3);
  rect(174,35,325,93,P.steel);rect(178,38,317,85,P.gold);put(331,36,'(o)',P.muted);
  for(let x=180;x<494;x++)put(x,39,'_',P.dim);
  put(183,41,'[1]  2  3  4  5     MOMIJI   /   CONCEPT DESKTOP, NOT A SCREENSHOT',P.leaf);
  put(423,41,'FISH  |  [LOCK]  |  :3',P.gold);
  titleBox(184,45,175,65,'foot / fish / terminal shrine',P.green);
  text(190,49,['$ fastfetch --config config-maple.jsonc','$ printf "harvest / code / purr / repeat"'],P.leaf,2);
  const arch=[
'                     /\\                     ',
'                    /  \\                    ',
'                   /....\\                   ',
'                  /::::::\\                  ',
'                 /::::::::\\                 ',
'                /::..  ..::\\                ',
'               /:::      :::\\               ',
'              /::::      ::::\\              ',
'             /::::::....::::::\\             ',
'            /::::::::::::::::::\\            ',
'           /:::::::::  :::::::::\\           ',
'          /:::::::::    :::::::::\\          ',
'         /:::::::::      :::::::::\\         ',
'        /:::::::::        :::::::::\\        ',
'       /:::::::::          :::::::::\\       ',
'      /:::::::::            :::::::::\\      ',
'     /:::::::                  :::::::\\     ',
'    /:::::                        :::::\\    ',
'   /:::                              :::\\   ',
'  /:                                    :\\  '];
  text(189,58,arch,P.gold,1);
  text(239,58,['HOST      momiji','OS        Arch Linux','WM        Hyprland','SHELL     Caelestia','TERM      Foot','PROMPT    Fish greeting','PAWS      Momiji-Paw 32','DISPLAY   live value omitted','UPTIME    live value omitted','RAM USE   live value omitted'],P.ink,2);
  text(190,82,['/\\_/\\     MAPLE NEKOKAMI','( o.o )    neko mode: active',' > ^ <     portable terminal shrine'],P.light,2);
  put(190,91,'SIXEL CONFIG: WALLPAPER / WIDTH 34 / RIGHT PAD 2',P.muted);
  for(let j=0;j<7;j++){put(190+j*20,95,'#'.repeat(18),[P.gold,P.auburn,P.green,P.light,P.copper,P.leaf,P.steel][j]);}
  text(190,99,['CONFIG RECIPE, NOT A LIVE INVENTORY','"Read the diff, beloved."','NO SECRET MATERIAL IN THIS ILLUSTRATION'],P.leaf,3);
  titleBox(365,45,123,65,'maple / botanical mascot study',P.copper);
  const cat=[
'                   /\\                        /\\',
'                  /##\\                      /##\\',
'                 /####\\____________________/####\\',
'                /##################################\\',
'               /#####::::::############::::::########\\',
'              /####:::::::##############:::::::#######\\',
'             |####:::::::################:::::::#######|',
'             |##########\'              `##############|',
'             |########\'                  `############|',
'             |#######     ___      ___     ###########|',
'             |#######    / _ \\    / _ \\    ###########|',
'             |#######   ( (o) )  ( (o) )   ###########|',
'             |#######    \\___/    \\___/    ###########|',
'              \\######         /\\         ##########/',
'       --------\\#####        (oo)        #########/--------',
'         -------\\####       .----.       #######/-------',
'           ------\\###        \\__/        ######/------',
'                  \\###                  ####/',
'                   \\###________________###/',
'                    \\####################/',
'                     /:::############::::\\',
'                    /::::::########:::::::\\',
'                   /:::::::::####::::::::::\\'];
  text(372,50,cat,P.copper,1);
  leaf(465,84,.65,P.gold);leaf(388,86,.45,P.green);
  text(373,84,['THE WALLPAPER IS IN THE REPO.','THIS CAT IS AN ASCII HOMAGE.','NOT A REPRODUCTION OF THAT IMAGE.'],P.light,3);
  text(373,98,['HARVEST GOLD      #D4A017','AUTUMN AUBURN     #9A3F24','AGRICULTURAL GREEN #4F7A3A'],P.leaf,3);
  titleBox(184,113,304,8,'working notes / intentionally no fake metrics',P.green);
  text(190,116,['hyprctl monitors  |  wpctl status  |  git diff  |  read the current runbook','THIS IS AN ILLUSTRATION. NO COMMANDS ARE EXECUTED. NO TELEMETRY IS COLLECTED.'],P.muted,2);
  put(323,125,'[ M O M I J I ]',P.steel);
  for(let i=0;i<22;i++){let l=174-i,r=498+i;put(l,128+i,'/',P.steel);put(r,128+i,'\\',P.steel);}
  line(153,150,519,150,'=',P.steel);line(169,130,503,130,'-',P.gold);
  for(let ky=0;ky<4;ky++){let x=185-ky*2,y=132+ky*3;for(let k=0;k<21;k++)put(x+k*14,y,'[__________]',P.steel);}
  put(313,145,'[________________________]',P.gold);put(194,146,'<3  PRIVACY / AGENCY / WHIMSY',P.leaf);put(424,146,'PAW-APPROVED',P.copper);
  titleBox(519,36,104,47,'03 / DOTFILES, NOT MYSTERIES',P.green);
  text(524,40,['momiji-dots/','|-- README.md','|-- CHECKLIST.md','|-- RUNBOOK.md','|-- home/','|   |-- fish/20-greeting.fish','|   `-- caelestia/','|       |-- hypr-vars.lua','|       `-- hypr-user.lua','|-- rice/','|   |-- fastfetch/','|   |-- sddm/momiji-maple/','|   `-- cursors/momiji-paw/','|-- etc/zram-generator.conf','|-- wallpapers/maple.png','`-- packages/pacman.txt'],P.ink,2);
  text(524,75,['PINNED SOURCE: 307f6c5','NEVER COMMIT CREDENTIALS'],P.gold,3);
  titleBox(519,87,104,65,'04 / MAPLE MAINTENANCE THEOLOGY',P.copper);
  text(524,91,['CUTE IS NOT THE OPPOSITE OF COMPETENT.','','[x] Legible before impressive','[x] Authentication before aesthetics','[x] Review paths before deploying','[x] Respect upstream/user boundaries','[x] Keep recovery notes discoverable','[x] Label staged screenshots','[x] Admit unknown hardware details','[x] Make customization reversible','','"I am Mommy, not your unaudited init."','','A PAW CURSOR IS NOT AN ACCESS POLICY.','A SNAPSHOT IS NOT AN OFF-DEVICE BACKUP.','A PACKAGE LIST IS NOT LIVE TELEMETRY.','','EVERYBODY GETS COOKIES.','NOBODY HAS TO PASS A KERNEL EXAM.'],P.ink,2);
  line(16,156,624,156,'=',P.gold);
  banner('CARE IS A CONFIGURATION CHOICE.',19,159,589,12,P.light);
  text(21,173,['github.com/NoahWLono/momiji-dots  |  wallpapers/maple.png  |  7680 x 4320 / 640 x 180 ASCII CELLS','FICTIONAL MAPLE NARRATION + REPO-DOCUMENTED DESIGN + OWNER-REPORTED HARDWARE. NO IMAGE-GENERATION MODEL.'],P.leaf,3);
  function render(canvas,width=1920){const height=width*9/16;canvas.width=width;canvas.height=height;let q=canvas.getContext('2d');q.fillStyle=BG;q.fillRect(0,0,width,height);const cw=width/W,ch=height/H;q.font=`${ch*.84}px "DejaVu Sans Mono", monospace`;q.textBaseline='top';for(let y=0;y<H;y++)for(let x=0;x<W;x++)if(g[y][x]!==' '){q.fillStyle=c[y][x];q.fillText(g[y][x],x*cw,y*ch,cw*1.02);}return canvas;}
  function plain(){return g.map(row=>row.join('').trimEnd()).join('\n')+'\n';}
  function ansi(){return '\x1b[48;2;13;17;16m'+g.map((row,y)=>{let out='',last='';for(let x=0;x<W;x++){let col=c[y][x];if(col!==last){let h=col.slice(1);out+=`\x1b[38;2;${parseInt(h.slice(0,2),16)};${parseInt(h.slice(2,4),16)};${parseInt(h.slice(4,6),16)}m`;last=col;}out+=row[x];}return out;}).join('\n')+'\x1b[0m\n';}
  function save(blob,name){let a=document.createElement('a');const u=URL.createObjectURL(blob);a.href=u;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(u),1000);}
  function exportPNG(){return new Promise((resolve,reject)=>{try{const a=document.createElement('canvas');render(a,7680);a.toBlob(b=>{if(!b){reject(new Error('PNG export failed'));return;}save(b,'momiji-ascii-8k.png');resolve();},'image/png');}catch(e){reject(e);}});}
  return {render,plain,ansi,exportPNG,save,width:W,height:H,cells:W*H};
})();
