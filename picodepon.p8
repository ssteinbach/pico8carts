pico-8 cartridge // http://www.pico-8.com
version 18
__lua__

bounceframecount = 10
coyotehangtime = 12
manualraiserepeatframes = 5
squashholdframes = 3
flashframes = 45
faceframes = 26
flashandfaceframes = 71
popoffset = 9
chainresetcount = 7
postclearholdframes = 3

bs_idle = 0
bs_matching = 1
bs_swapping = 2
bs_coyote = 3
bs_postclearhold = 4
bs_garbage = 5
bs_garbagematching = 6

blocktileidxs = {
  1, 17, 33, 49, 8, 24, 40
}

bounceframes = {
 0, 3, 3, 3,
 4, 4, 4, 4, 2, 2, 2, 0
}

squashframes = {
 2, 0, 3, 4, 3, 0
}

function block_new()
 return {
 	btype=0,
 	state=bs_idle,
 	count=0,
 	count2=0,
 	fallframe=0,
 	chain=0,
 	fallenonce=false,
 	garbagex=0,
 	garbagey=0,
 	garbagewidth=0,
 	garbageheight=0,
 }
end

cs_idle = 0
cs_swapping = 1

function board_new()
	local b = {}

	b.blocks = {}
	for i = 1, 13 do
  local row = {}
  b.blocks[i] = row
  
  for j = 1, 6 do
   row[j] = block_new()
  end
	end

 b.blocktypecount = 6


	b.cursx = 0
	b.cursy = 6
 b.cursstate = cs_idle
 b.curscount = 0
 b.cursrepeatpause = 0
 b.cursrepeatcount = 0
 b.cursbumpx = 0
 b.cursbumpy = 0
 b.contidx = 0
 
 b.rowstart = 0
 b.raiseoffset = 0
 b.manualraise = 0

 b.nextlinerandomseed =
   rnd(32767)
 
 b.x = 8
 b.y = 32
 
 b.matchrecs = {}
 
 b.autoraisehold = 0
 b.autoraisecounter = 0
 b.autoraisespeed = 60
 
 b.shakecount = 0
 
 b.pendinggarbage = {}
 return b

end

function board_getrow(b, idx)
 return b.blocks[(
   (idx + b.rowstart - 1) % 13
   		) + 1]
   	
end

function board_fill(b, startidx)
 local horzruntype = 0
 local vertruntype = 0
 for y = 13, startidx, -1 do
  local row = board_getrow(b, y)
  for x = 1, 6 do
   if (x == 3 or x == 4) and
     y < 10 then
    goto cont
   end
   
   
   horzruntype = 0
   if x > 2 then
    if row[x - 2].btype ==
      row[x - 1].btype then
     horzruntype =
       row[x - 1].btype
    end
   end
   vertruntype = 0
   if y < 11 then
    local row2 =
      board_getrow(b, y + 1)
    local row3 =
      board_getrow(b, y + 2)
  
      
    if row2[x].btype ==
      row3[x].btype then
     vertruntype =
       row2[x].btype
    end 
   end
			
			
   
   
   if horzruntype > 0 or
     vertruntype > 0 then
   
    local types = {}
    for t = 1, b.blocktypecount
      do
     if t != horzruntype and
       t != vertruntype then
      types[#types + 1] = t
     end
    end
 
    row[x].btype = types[
      flr(rnd(#types)) + 1]
  
   else    
    row[x].btype =
      flr(rnd(
        b.blocktypecount)) + 1
   end
  
   
   ::cont::
   
  end
 end
 
 
 board_appendgarbage(b,
   3, 1)
 board_appendgarbage(b,
   3, 1)
 board_appendgarbage(b,
   6, 3)
 
 
 --board_addgarbage(b,
 --  1, 1, 3, 1)
 --board_addgarbage(b,
 --  4, 1, 3, 2)
 
 
end

function board_addgarbage(b,
  x, y, width, height,
    forcey, forceh)
 
 for yy = y - (height - 1), y do
  
  if yy > 0 then
   local row =
     board_getrow(b, yy)
   
   for xx = x, x + width - 1 do
    local bk = row[xx]
    
    bk.state = bs_garbage
		  bk.garbagex = xx - x
		  bk.garbagey = -(yy - y)
		  bk.garbagewidth = width
		  bk.garbageheight = height
		  bk.btype = 10
		  bk.fallenonce = false
		  
		  if forcey then
		   bk.garbagey = forcey
		  end
		  if forceh then
		   bk.garbageheight = forceh
		  end
   end
  end
  --for xx = 
 end

end


function _cursdir(b, bidx)
 
 if not press(bidx, b.contidx)
   then return false end
  
 if newpress(bidx, b.contidx)
		 then
		b.cursrepeatpause = 0
		b.cursrepeatcount = 0
	end

 if b.cursrepeatpause == 0
   then
  if b.cursrepeatcount == 0
    then
   b.cursrepeatcount = 1
   b.cursrepeatpause = 8

  else
   b.cursrepeatpause = 0
   if frame % 2 > 0 then
     -- play sound
  	end
   
  end
  return true
 else
  b.cursrepeatpause -= 1
 end

 return false
end

function stateisswappable(s)
 if s == bs_idle
   or s == bs_postclearhold
   then
  return true
 end
 return false
end

function hasblock(bk, bkbelow)
 if not bk then
  return false
 end
 if bk.btype > 0 and
   (not bkbelow or
     bkbelow.btype > 0)
   then
  return true
 end
 return false
end

function canswap(bk, bkbelow)
  if bk.btype == 0 or (
     not bkbelow
     or bkbelow.btype > 0
     ) then
   return true
  end
  return false
end

function board_getcursblocks(
	 b, below)
 local off = 1
 if below then
  off += 1
 end
 local row =
    board_getrow(b, b.cursy
    		+ off)
 
 return row[b.cursx + 1],
   row[b.cursx + 2]
end

cursshakeframes = {
 -1, -1, 0, 0, 1, 1, 0, 0
}
function board_cursinput(b)
	
	b.cursbumpx = 0
	b.cursbumpy = 0
	
	if b.cursstate != cs_idle then
	 return
	end
 
 if newpress(5, b.contidx) then
  local bk1, bk2 =
    board_getcursblocks(b)
   
  local bk1below = nil
  local bk2below = nil
  if b.cursy < 12 then
  	bk1below, bk2below =
  	  board_getcursblocks(b, 1)
  	--[[
  	local belowrow =
  	  board_getrow(b,
  	    b.cursy + 2)
   bk1below =
     belowrow[b.cursx + 1]
   bk2below =
     belowrow[b.cursx + 2]
  --]]
  end
  
  if stateisswappable(bk1.state)
    and stateisswappable(
      bk2.state)
    and (hasblock(bk1, bk1below)
     or hasblock(bk2, bk2below))
    and (canswap(bk1, bk1below)
     and canswap(bk2, bk2below))
    then
   -- swap shit
   bk1.state = bs_swapping
   bk2.state = bs_swapping
   b.cursstate = cs_swapping
   b.curscount = 0
   sfx(1)
   return
  else   
   maskpress(bnot(shl(1, 5)),
     b.contidx)
   -- todo pending bump shake   
   
   if (
     stateisswappable(bk1.state)
     and hasblock(bk1, bk1below)
     and canswap(bk1, bk1below)
     ) or (
     stateisswappable(bk2.state)
     and hasblock(bk2, bk2below)
     and canswap(bk2, bk2below)
     ) then
    
    b.cursbumpx = 
      cursshakeframes[
        (frame % 8) + 1]
   end
  end
 
 
 
 end
 
 
 if b.cursy > 0 and
 	 (not (b.cursy == 1
 	   and b.raiseoffset > 3))
 	 and _cursdir(b, 2) then
  b.cursy -= 1
  sfx(3)
 end
 
 if b.cursy < 11 and
 	 _cursdir(b, 3) then
  b.cursy += 1
  sfx(3)
 end
 
 if b.cursx > 0 and
 	  _cursdir(b, 0) then
  b.cursx -= 1
  sfx(3)
 end
 
 if b.cursx < 4 and
   _cursdir(b, 1) then
  b.cursx += 1
  sfx(3)
 end
 
end



function board_raise(b)
	local toprow =
	  board_getrow(b, 1)

 for i = 1, 6 do
  if toprow[i].btype > 0 then
   b.manualraise = 0
   return
  end
 end

 b.raiseoffset += 1
 
 if b.raiseoffset == 8 then
  b.raiseoffset = 0
  if b.cursy > 0 then
   b.cursy -= 1
  end
 
  b.rowstart =
    (b.rowstart + 1) % 13
  
  b.nextlinerandomseed += 1
  srand(b.nextlinerandomseed)
  
  local botrow =
    board_getrow(b, 13)
  
  local runlen = 0
  local lasttype = 255
  for i = 1, 6 do
   local t = flr(
     rnd(b.blocktypecount))
   
   if t == lasttype then
    runlen += 1
    if runlen > 2 then
     t = t + flr(rnd(
       b.blocktypecount - 1)
         ) + 1
     t = t % b.blocktypecount
     runlen = 1
    end
   else
    runlen = 1
   end
   
   if rnd(128) < 8 then
    t = 6
   end 
   
   botrow[i].count = 0
   botrow[i].chain = 0
   botrow[i].state = bs_idle
   botrow[i].btype = t + 1
   lasttype = t
  end
  
  
  for i = 1, #b.matchrecs do
   b.matchrecs[i].y -= 1
  end
  --todo, adjust matches
 
 elseif b.raiseoffset == 2 then
  if b.cursstate == cs_idle and
    b.cursy == 0 then
   b.cursy = 1
  end
 end

end

function runrec_new()
 return {btype=0, len=0}
end

function matchrec_new()
 return {
  x=0,
  y=0,
  dur=0,
  chain=0,
  seqidx=0,
  puffcount=255,
 }
end


function board_step(b)

 if press(4, b.contidx) then
  
  local raise = true
  if b.raiseoffset == 0 then
   if newpress(4, b.contidx)
     then
    b.manualraise =
      manualraiserepeatframes
   else
    b.manualraise -= 1
    if b.manualraise > 0 then
     raise = false
    end
   end
  else
   b.manualraise =
     manualraiserepeatframes
  end
  
  if raise then
   board_raise(b)
  end
 elseif b.raiseoffset > 0 and
   b.manualraise > 0 then
   board_raise(b)
 else
  b.manualraise = 0
  
  --todo, autoraise
  if #b.matchrecs == 0 then
   b.autoraisecounter += 0.5
   if b.autoraisecounter >=
     b.autoraisespeed then
    b.autoraisecounter = 0
    board_raise(b)
   end
  
  end
  
 end
 
 board_cursinput(b)
 
 if b.cursstate == cs_swapping
   then
  local bk1, bk2 =
    board_getcursblocks(b)
  
  if b.curscount < 3 then
   b.curscount += 1
  else
   b.cursstate = cs_idle
   local t = bk1.btype
   bk1.btype = bk2.btype
   bk2.btype = t
   bk1.state = bs_idle
   bk2.state = bs_idle
   
   
   
   function postswap(x, y)
   	local bmid = board_getrow(
   		 b, y)[x]
   	
   	local bdown = nil
   	if y < 13 then
   	 bdown = board_getrow(
   		 b, y + 1)[x]
   	end
   	
   	local bup = nil
   	if y > 1 then
   	 bup = board_getrow(
   		 b, y - 1)[x]
   	end
   	
   	if bmid.btype > 0 then
   	 if bdown then
   	  if bdown.btype == 0 then
   	   bdown.state = bs_coyote
   	   bdown.count =
   	     coyotehangtime
   	  end
   	 end
   	 bmid.count = 0
   	else
   	 if bup then
   	  if bup.btype > 0 then
   	   bmid.state = bs_coyote
   	   bmid.count = coyotehangtime
   	  end
   	 end
   	end
   end
   
   postswap(b.cursx + 1,
     b.cursy + 1)
   postswap(b.cursx + 2,
     b.cursy + 1)
     
   -- unset dpad states
   maskpress(bnot(7),
     b.contidx)
   
  end
 end
 
 -- board scan
 local rows = {}
 for i = 1, 13 do
  rows[i] = board_getrow(b, i)
 end
 
 local horzrun = runrec_new()
 local vertruns = {}
 
 for i = 1, 6 do
  vertruns[i] = runrec_new()
 end
 
 local newmatchminx = 7
 local newmatchminy = 13
 
 local matchseqmap = {}
 local newmatchseqs = {}
 
 local newmatchchainmax = 0
 local garbagefallarea = 0
 
 local checkhorzrun =
   function(x1, y1)
  if horzrun.len < 3 then
   return
  end
  -- todo
  local matchseq = {}
  add(newmatchseqs, matchseq)
  local row = board_getrow(
    b, y1)
  local pad = flashandfaceframes
  local dur = pad +
      horzrun.len * popoffset
  
  
  local chainmax = 0
  
  -- todo, metal match count
  local rx = x1 - horzrun.len
  newmatchminy = min(
     newmatchminy, y1)
  
  for r = 1, horzrun.len do
   local runbk =
     row[rx]
   
   runbk.state = bs_matching
   runbk.count = 0
   runbk.count2 = pad

   matchseqmap[
     rx + shl(y1, 4)] =
       matchseq

   local mrec = matchrec_new()
   mrec.x = rx
   mrec.y = y1
   mrec.dur = dur
   mrec.seqidx = r - 1
   add(matchseq, mrec)
   
   chainmax = max(chainmax,
     runbk.chain + 1)
   mrec.chain = chainmax
   newmatchminx = min(
     newmatchminx, rx)
     
   pad += popoffset
   rx += 1
  end
  
  if chainmax > 1 then
   for i = 1, #matchseq do
    matchseq[i].chain =
      chainmax
   end
  end
  
  newmatchchainmax = max(
    newmatchchainmax, chainmax)
 end
 
 --todo function checkvertrun
 local checkvertrun = function(
   x1, y1)
  if vertruns[x1].len < 3 then
   return
  end
  local runlen =
    vertruns[x1].len
  local runlendur =
    runlen * popoffset
  
  newmatchminx = min(
     newmatchminx, x1)
     
  local pad = flashandfaceframes
  local dur = pad + runlendur
  local ry = y1
  local chainmax = 0
  local crosschainmax = 0
  local runoffset = 0
  local runbtype =
    vertruns[x1].btype
  
  local hmatchseq = nil
  
  for r = 1, runlen do
   local runbk =
     board_getrow(b, ry)[x1]
   
   local key = x1 + shl(ry, 4)
   if not hmatchseq and
     matchseqmap[key] then
    hmatchseq =
      matchseqmap[key]
    
    pad = hmatchseq[1].dur
    dur = pad + runlendur
    
    for i = 1, #hmatchseq do
     hmatchseq[i].dur = dur
    end  
    
    chainmax = max(chainmax,
      hmatchseq[1].chain)
   else
    chainmax = max(chainmax,
      runbk.chain + 1)
   end
     
   
   ry += 1
  end
 
  local matchseq = nil
  if hmatchseq then
   matchseq = hmatchseq
   for i = 1, #matchseq do
    matchseq[i].chain =
      chainmax
   end
   runoffset = #matchseq - 1
  else
   matchseq = {}
   add(newmatchseqs, matchseq) 
  end
  
  local mrec = nil
  ry = y1
  for r = 1, runlen do
   local runbk =
     board_getrow(b, ry)[x1]
   
   if runbk.state ==
     bs_matching then
    goto cont
   end
   
   runbk.state = bs_matching
   runbk.count = 0
   runbk.count2 = pad
   
   mrec = matchrec_new()
   mrec.x = x1
   mrec.y = ry
   mrec.dur = dur
   mrec.chain = chainmax
   mrec.seqidx =
     r - 1 + runoffset
   add(matchseq, mrec)
   
   newmatchminy = min(
     newmatchminy, ry)
   
   --todo: metal
   --todo: seqidx
   
   ::cont::
   
  	ry += 1
  	pad += popoffset
  end
  
  newmatchchainmax = max(
    newmatchchainmax, chainmax)
 
 end
 
 local prevrow = nil
 local row = nil
 for y = 12, 1, -1 do
  row = rows[y]
  horzrun.len = 0
  horzrun.btype = 0
  for x = 1, 6 do
   
   local bk = row[x]
   if bk.state == bs_coyote or
     bk.state ==
       bs_postclearhold
     then
    bk.count -= 1
    if bk.count <= 0 then
     bk.state = bs_idle
    end
   end
  
   if bk.state == bs_idle
     and bk.btype > 0 then
    
    if prevrow then
   	
     local bkbelow = prevrow[x]

     if bkbelow.state == bs_idle
       and bkbelow.btype == 0
       then
						--stop()
						 
      bkbelow.btype = bk.btype
      bkbelow.fallframe =
        frame
      bkbelow.count = 0
      bkbelow.chain = bk.chain
      
      bk.btype = 0
      bk.count = 0
      bk.chain = 0
      
      horzrun.len = 0
      horzrun.btype = 0
      
      goto cont
      
     end
    end
    
    -- was falling but stopped
    if bk.fallframe ==
      pframe then
     bk.count =
       bounceframecount
     --sfxdrop
     sfx(2)
    else
     -- not falling
     if bk.count > 0 then
      bk.count -= 1
      
      -- todo chain reset
      if bk.count ==
       chainresetcount then
       bk.chain = 0
      end
     
     end
    
     
    end
    
    if (bounceframecount -
      bk.count) < 2 then
     
     checkhorzrun(x)
     horzrun.btype = 0
     horzrun.len = 1
     
     checkvertrun(x, y + 1)
     vertruns[x].btype = 0
     vertruns[x].len = 1
    
    else
     
     if horzrun.btype ==
       bk.btype then
      horzrun.len += 1
     else
      --we don't match but
      --what's before us might
      checkhorzrun(x, y)
      horzrun.btype = bk.btype
      horzrun.len = 1
     end
     
     if vertruns[x].btype ==
       bk.btype then
      vertruns[x].len += 1
      
      if y == 1 then
       checkvertrun(x, 1)
      end
     else
      checkvertrun(x, y + 1)
      vertruns[x].btype =
        bk.btype
      vertruns[x].len = 1
     end
     
     
    end
    
   else
    checkhorzrun(x, y)
    horzrun.btype = 0
    horzrun.len = 0
    
    checkvertrun(x, y + 1)
    vertruns[x].btype = 0
    vertruns[x].len = 0
    
   
    -- todo, garbage
    
    if prevrow and
      bk.state == bs_garbage and
      bk.garbagex == 0 then
      
      --local bkbelow =
      --  prevrow[x]
      
      local clearbelow = true
      for i = x,
        x + bk.garbagewidth - 1
        do
       local bbk = prevrow[i]
       if bbk.state != bs_idle
         or bbk.btype != 0 then
        clearbelow = false
        break
       end
      end
      
      if clearbelow then
       for i = x,
         x + bk.garbagewidth - 1
         do
        prevrow[i] = row[i]
        row[i] = block_new() 
        prevrow[i].fallframe =
          frame
       end     
       
       if y == 1 and
         bk.garbagey <
          bk.garbageheight - 1
          then
        board_addgarbage(b, x, 1,
          bk.garbagewidth, 1,
          bk.garbagey + 1,
          bk.garbageheight)
       end
      
      else
       if bk.fallframe ==
         pframe then
         
        sfx(2)
       elseif bk.garbagey == 0
         and not bk.fallenonce
         then
        bk.fallenonce = true
        garbagefallarea = 
          garbagefallarea +
            bk.garbagewidth *
            bk.garbageheight
            
        
       end
      end
      
    end
    
   end
   
   ::cont::
   
  end
  checkhorzrun(7, y)
  prevrow = row
 end
 
 local matchcount = 0
 
 if #newmatchseqs > 0 then
  --b.matchrecs
  
  local seqidxstartr = {0}
  
  --todo, check garbage
  for i = 1, #newmatchseqs do
   
   local ms = newmatchseqs[i]
   matchcount += #ms
   for j = 1, #ms do
    local m = ms[j]
    add(b.matchrecs, m)
    
    local _breakgarb =
      function(xo, yo)
     if board_getrow(b,
       m.y + yo)[
         m.x + xo].state ==
           bs_garbage then
      
      board_breakgarbage(
       b, m.x + xo, m.y + yo,
         m.dur, m.chain,
           seqidxstartr) 
     end
    end
    
    
    -- left
    if m.x > 1 then
     _breakgarb(-1, 0)
    end
    
    if m.x < 6 then
      _breakgarb(1, 0)
    end
    
    if m.y > 1 then
     _breakgarb(0, -1)
    end
    
    if m.y < 12 then
     _breakgarb(0, 1)
    end
    
   end
   
  end
  --transfer to active match
 end
 
 local activematches = {}
 
 for i = 1, #b.matchrecs do
  local m =
    b.matchrecs[i]
  
  local keep = true
  if m.dur > 0 then
   local bk = board_getrow(b,
     m.y)[m.x]
   
   bk.count = bk.count + 1
   
   if bk.count >= m.dur then
    m.dur = 0
    bk.count =
      postclearholdframes
    if bk.state == bs_matching
      then
     bk.state =
       bs_postclearhold
     
     
     bk.btype = 0
     bk.chain = 0
     
     -- walk up and max chain
     for y = m.y - 1, 1, -1 do
      -- todo
      local runbk =
        board_getrow(b, y)[m.x]
       
      if runbk.btype == 0 or
        (runbk.state != bs_idle
        and runbk.state !=
          bs_garbage) then
       break
      end
      
      runbk.chain = max(
        runbk.chain, m.chain)
     end
     
    elseif bk.state ==
      bs_garbagematching then
     bk.state =
       bs_postclearhold 
     bk.chain = max(bk.chain,
       m.chain)
     
     bk.fallframe = frame
    
    end
   elseif bk.count == bk.count2
     then
    m.puffcount = 0
    --sfxpop
    sfx(0, -1, min(
      m.seqidx, 31), 1)
   end
  
  end
  
  if m.puffcount != 255 then
   if m.puffcount >= 18 then
    if m.dur == 0 then
     keep = false
     
    end
   else
    m.puffcount += 1
   end
  end
  
  
  if keep then
   add(activematches, m)
  end
 end
 
 b.matchrecs = activematches
 

 
 local buboffset = 0
 if matchcount > 3 then
  local mx =
    (newmatchminx - 1) * 8
      + b.x - 4
  
  
  local my =
    (newmatchminy - 1) * 8
      + board_getyorg(b) - 4
 
  add(matchbubs, matchbub_new(
    0, matchcount, mx, my))
 
  buboffset = 11
  
 end
 
 if newmatchchainmax > 1 then
  local mx =
    (newmatchminx - 1) * 8
      + b.x - 5
  
  local my =
    (newmatchminy - 1) * 8
      + board_getyorg(b) - 4
  my -= buboffset
 
  add(matchbubs, matchbub_new(
    1, newmatchchainmax, mx, my))
  
 end
 
 if garbagefallarea > 0 then
  if garbagefallarea > 4 then
   b.shakevalues = shakelarge
 	else
 	 b.shakevalues = shakesmall
 	end
  b.shakecount = #b.shakevalues
 end
 
 board_pendingstep(b)
end

function block_draw(b, x, y, ry,
  squashed)
 if b.btype == 0
 		or b.bstate == bs_swapping
 		then
 	return
 end
 
 if b.state == bs_idle then
  local idx = blocktileidxs[
  		b.btype]
  
  if ry == 13 then
   idx += 1
  elseif b.count > 0 then
   idx += bounceframes[b.count]
  elseif squashed then
  	-- todo column squash
  	idx = idx + squashframes[
  	  squashframe + 1]
  	
  end
  
  spr(idx, x, y)
 
 
 elseif b.state == bs_matching
   then
  
  local idx = blocktileidxs[
  		b.btype]
  
  if b.count < flashframes then
   if frame % 2 == 0 then
    idx += 6
   end
  elseif b.count < b.count2 then
   idx += 5
  else
   return
  end
  
  spr(idx, x, y)
 
 elseif b.state == bs_garbage
   then
  
  
 	if b.garbagex == 0 and
 	  b.garbagey == 0 then
 	 
 	 local top = y -
 	   (b.garbageheight - 1) * 8
 	 
 	 local right = x +
 	   b.garbagewidth * 8 - 1
 	 
 	 local left = x
 	 local bottom = y + 7
 	 
 	 rectfill(left, top, right,
 	   bottom, 0)
 	 rect(left + 1, top + 1,
 	   right - 1, bottom - 1, 5)
 	 
 	 palt(13, true)
 	 
   local idx = 31
   if (frame % 120) < 10 then
    idx = 47
   end
   
 	 spr(idx,
 	   (right - left) / 2 +
 	   left - 3,
 	   (bottom - top) / 2 +
 	   top - 3, 1, 1,
 	   	frame % 320 < 160
 	     )
 	  
 	 palt(13, false)
 	
 	end
 	 	
 
 elseif b.state ==
   bs_garbagematching then
  
  local idx = 62
  if b.count < flashframes then
   if frame % 2 == 0 then
    idx = 63
   end
  elseif b.count < b.count2 then
  else
   idx = blocktileidxs[
  		b.btype]

  end
  
  spr(idx, x, y)
  
 end
 
end

function board_getyorg(b)
 local y = b.y - b.raiseoffset
 
 if b.shakevalues then
  y = y - b.shakevalues[
    b.shakecount] / 2
 end

 return y
end

function board_draw(b)
 local x = b.x
 local y = b.y
 rectfill(x - 2, y - 1,
   x + 1 + 6 * 8,
   y + 1 + 12 * 8, 13)
 
 rect(x - 1, y,
   x + 6 * 8,
   y + 1 + 12 * 8, 1)
   
 rect(x - 2, y - 1,
   x + 1 + 6 * 8,
   y + 1 + 12 * 8, 7)
   
 
 local r1 = board_getrow(b, 1)
 local r2 = board_getrow(b, 2)
 local squashed = {}
 for i = 1, 6 do
  squashed[i] = (
    r1[i].btype > 0 or
      r2[i].btype > 0)
 end
 
 clip(0, y, 128, 128 - y)
 
 y -= b.raiseoffset
	
	if b.shakecount > 0 and
	  b.shakevalues then
	 
	 b.shakecount -= 1
	 y = y - b.shakevalues[
	   b.shakecount + 1] / 2
	else
	 b.shakevalues = nil
	end
	
	local yy = y
	
	-- draw blocks
	for ty = 1, 13 do
	 local row = board_getrow(b, ty)
		local xx = x
	 
	 for tx = 1, 6 do
	  local bk = row[tx]
	  
	  block_draw(bk, xx, yy, ty,
	    squashed[tx])
	  
	  xx += 8
	 end
	
		yy += 8
	end
	
	clip()
	
	palt(12, true)
	for i = 1, #b.matchrecs do
	 local m = b.matchrecs[i]
	 
	 --[[
	 local sx = (m.x - 1) * 8 + x
	 local sy = (m.y - 1) * 8 + y
	 print(m.seqidx, sx, sy) 
	 --]]
	 
	 if m.puffcount != 255 and 
	   m.puffcount < 18 then
	 
	  local sx = (m.x - 1) * 8 + x
	  local sy = (m.y - 1) * 8 + y
	  
	  local n = m.puffcount / 17
	  local g = n * 16
	  local d = (n^0.75) * 16
	 	spr(48, sx - d, sy - d + g)
	 	spr(48, sx + d, sy - d + g)
	 	spr(48, sx - d, sy + d + g)
	 	spr(48, sx + d, sy + d + g)
	 	
	 	
	 	
	 end
	
	end
	palt(12, false)
	-- draw cursors

	local cx = x + b.cursx * 8
	local cy = y + b.cursy * 8
	
	cx += b.cursbumpx
	cy += b.cursbumpy
	
	  -- todo draw swapping blocks
	if b.cursstate == cs_swapping
	  then
	 local bk1, bk2 =
  	  board_getcursblocks(b)
  	
  if bk1.btype > 0 then
   local idx = blocktileidxs[
  		 bk1.btype]
  	
  	spr(idx, cx + b.curscount * 2,
  	  cy)
  end
  
  if bk2.btype > 0 then
   local idx = blocktileidxs[
  		 bk2.btype]
  		 
  	spr(idx, cx + 8
  	  - b.curscount * 2, cy)
  end
  
	end
	
	local off = 0
	if frame % 32 < 15 then
	 off = 1
	end
	
	palt(13, true)
	spr(16, cx - 4 - off,
	  cy - 4 - off)
	spr(16, cx - 4 - off,
		 cy + 3 + off, 1, 1,
		 		false, true)
	spr(16, cx + 12 + off,
		 cy - 4 - off, 1, 1,
		 		true, false)
	spr(16, cx + 12 + off,
		 cy + 3 + off, 1, 1,
		 		true, true)
	spr(32, cx + 4,
		 cy - 4 - off, 1, 1)
	spr(32, cx + 4,
		 cy + 3 + off, 1, 1,
		   false, true)
	
	board_drawpending(b)
	palt(13, false)
	
end

function board_breakgarbage(
  b, x, y, basedur, chain,
    seqidxstartr)
 local bk =
   board_getrow(b, y)[x]
 
 if bk.state != bs_garbage then
  return 0
 end
 
 chain = max(bk.chain, chain)
 
 x -= bk.garbagex
 y += bk.garbagey
 
 bk = board_getrow(b, y)[x]
 
 if bk.state != bs_garbage then
  return 0
 end
 
 bk.state = bs_garbagematching
 
 local w = bk.garbagewidth
 local h = bk.garbageheight
 
 -- trim off top
 if y < h then
  local extrarows = h - y
  h -= extrarows
  --todo, prepend rest
 end
 
 local numblocks = w * h
 
 local hmax = 12
 local wmax = 6
 
 local dur = basedur + (
   numblocks * popoffset)
 local pad = basedur
 
 local maxdur = dur
 local maxdurtmp = nil
 
 local matchrecs = {}
 
 local seqidx = seqidxstartr[1]
 seqidxstartr[1] += numblocks
 
 for i = 0, h - 1 do
 	if y < 1 then
 	 break
 	end
 	local rx = x + (w - 1)
 	
 	local bk = board_getrow(
 	  b, y)[rx]
 	
 	
 	local _check = function
 	  (xx, xo, yo)
 	 local bk2 =
 	   board_getrow(b, y + yo)[
 	     xx + xo]
 	 
 	 if bk2.state == bs_garbage
 	   and bk2.btype ==
 	     bk.btype then
 	  return max(
 	    board_breakgarbage(b,
 	      xx + xo, y + yo, dur,
 	        chain,
 	          seqidxstartr),
 	            maxdur)
 	 end
 	 
 	 return maxdur
 	end
 	
  
 	-- check left
 	if x > 1 then
 		maxdur = _check(x, -1, 0)
 	end
 	
 	
 	-- check right
 	if rx < wmax then
 		maxdur = _check(rx, 1, 0)
 	end
 	
 	for j = 0, w - 1 do
 	 
 	 bk = board_getrow(b, y)[rx]
 	 
 	 --check down
 	 if i == 0 and y < 12 then
 	  maxdur = _check(rx, 0, 1) 
 	 end
 	 
 	 --check up
 	 if y > 1 and i == h - 1 then
 	  maxdur = _check(rx, 0, -1)
 	 end
 	 
 	 
 	 local m = matchrec_new()
 	 m.x = rx
 	 m.y = y
 	 m.dur = dur
 	 m.chain = chain
 	 seqidx += 1
 	 m.seqidx = seqidx
 	 bk.count = 0
 	 bk.count2 = pad
 	 bk.btype = flr(rnd(
 	   b.blocktypecount)) + 1
 	 bk.state =
 	   bs_garbagematching
 	 rx -= 1
 	 pad += popoffset
 	 
 	 add(b.matchrecs, m)
 	 add(matchrecs, m)
 	end
 	
 	y -= 1
 end
 
 if maxdur > dur then
  for i = 1, #matchrecs do
   matchrecs[i].dur = maxdur
  end
 
 end
 
 return maxdur   
end


function hexstr2array(s)
 local a = {}
 --tonum
 for i = 1, #s do
  add(a, tonum(
    '0x' .. sub(s, i, i)))
 end
 return a
end

function _init()
 frame = 2
 pframe = 1
 cstate = 0
 prevcstate = 0
 squashframe = 0
 squashcount = 0

 shakesmall = hexstr2array(
  "010011001110001111")
 shakelarge = hexstr2array(
  "010101010101010010010011001100111023332111456665422269abbbba8"
	)


 boards = {board_new(),
   board_new()}

 boards[1].x = 3
 boards[2].x = 77
 boards[2].contidx = 1
 
 boards[2].nextlinerandomseed =
   boards[1].nextlinerandomseed
 local s = rnd(31767)
 srand(s)
 board_fill(boards[1], 6)
 srand(s)
 board_fill(boards[2], 6)

 matchbubs = {}

end

function _press(
  bidx, cidx, state)
 if cidx > 0 then
  bidx += 8
 end
 local i = shl(1, bidx)
 
 if band(i, state) > 0 then
  return true
 end
 
 return false
end

function press(bidx, cidx)
  return _press(
    bidx, cidx, cstate)
end

function newpress(bidx, cidx)
 if not press(bidx, cidx) then
  return false
 end

	if _press(bidx, cidx,
	  prevcstate) then
	 return false
	end
	
	return true
end

function maskpress(bidx, cidx)
 local v = nil
 if cidx > 0 then
  v = shl(bidx, 8) + 255
 else
  v = shl(255, 8) + bidx
 end
 
 cstate = band(cstate, v)

end

-- todo, encode token-free
matchbubyoffsets = {
 1, 1, 1, 1, 1, 0, 1, 0,
 1, 0, 1, 0, 1, 0, 0, 1,
 0, 0, 0, 0, 1, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 1, 0, 0, 0, 0,
}


function _update60()
	pframe = frame
	frame += 1
	
	prevcstate = cstate
	cstate = btn()
	
	squashcount =
	  (squashcount + 1) % 3
	
	if squashcount == 0 then
	 squashframe =
	   (squashframe + 1) % 6
	end
	
	for i = 1, #boards do
	 board_step(boards[i])
	end
	
	local newmatchbubs = {}
	for i = 1, #matchbubs do
	 local mb = matchbubs[i]
	 mb.count += 1
	 if mb.count <
	   #matchbubyoffsets then
	  mb.y = mb.y -
	    matchbubyoffsets[
	      mb.count] / 2
	  add(newmatchbubs, mb)
	 end
	
	end
	matchbubs = newmatchbubs
	
end

function _draw()
 cls()
 rectfill(0, 0, 127, 127, 5)

 palt(0, false)
 
 for i = 1, #boards do
	 board_draw(boards[i])
	end
	
 palt(0, true)
 
 for i = 1, #matchbubs do
  matchbub_draw(matchbubs[i])
 end
 
end

function matchbub_new(
  bubtype, value, x, y)
 return {
  bubtype = bubtype,
  value = value,
  x = x,
  y = y,
  count = 0
 }
end

function matchbub_draw(mb)
 palt(13, true)
 palt(0, false)
 local offset = 7
 local textoffset = 6
 local bgs = 64
 if mb.bubtype > 0 then
  pal(3, 8)
  if mb.bubtype == 2 then
   pal(3, 1)
   bgs = 67
  end
  
  offset = 8
  textoffset = 8
 end

 spr(bgs, mb.x, mb.y)
 spr(bgs, mb.x +
   offset, mb.y,
     1, 1, true, false)
 
 spr(bgs + 1, mb.x, mb.y + 8)
 spr(bgs + 1, mb.x + offset,
    mb.y + 8, 1, 1, true, false)
 
 if mb.bubtype > 0 then
  spr(66, mb.x + 4, mb.y + 6)
 end
 
 local v = mb.value
 if v > 9 then
  v = "+"
 end
 print(v,
   mb.x + textoffset,
     mb.y + 6, 0)
 
 print(v,
   mb.x + textoffset,
     mb.y + 5, 7)
 
 pal()
 palt()
end


function pendinggarbage_new(
  width, height, forcex)
 
 local pg = {
  count = 60,
  width = width,
  height = height,
  forcex = forcex
 }
 
 if height > 1 then
  pg.bub = matchbub_new(
    2, height, 0, 0)
 end
 
 return pg
end

function board_appendgarbage(b,
  width, height, forcex)
 
 add(b.pendinggarbage,
   pendinggarbage_new(width,
     height, f0rcex))
end

function board_pendingstep(b)
 
 while #b.pendinggarbage > 0 do
  local pg =
    b.pendinggarbage[1]
  
  if pg.count > 0 then
   pg.count -= 1
   return
  end 
  
  local row =
    board_getrow(b, 1)
  
  local dropx = nil
  if b.forcex then
   for i = b.forcex,
     b.forcex + pg.width - 1 do
    
    if row[i].state != bs_idle
      or row[i].btype > 0 then
     return
    end  
    dropx = b.forcex
   end
  else
   local possiblespots = {}
   
   for i = 1, 7 - pg.width do
    
    for j = 1, pg.width do
     local bk = row[i + j - 1]
     
     if bk.state != bs_idle or
       bk.btype != 0 then
      goto cont 
     end
     
    end  
    
    add(possiblespots, i)
    
    ::cont::
   end
   
   if #possiblespots > 0 then
    dropx = possiblespots[
      flr(rnd(
        #possiblespots)) + 1]
   end
  end
  
  if not dropx then
   return
  end
  
  del(b.pendinggarbage, pg)
  
  board_addgarbage(b, dropx, 1,
    pg.width, pg.height)
  
 end
 
end

function board_drawpending(b)

 
 
	local x = b.x
	local y = b.y - 11
 for i = 1, min(4,
   #b.pendinggarbage) do
  
  --palt(13, true)
  --palt(0, false)
  
  local pg =
    b.pendinggarbage[i]
  
  if pg.bub then
   
   pg.bub.x = x - 1
   pg.bub.y = y - 5
   
   matchbub_draw(pg.bub)
   x += 11
   
   palt(0, false)
  else
   
   spr(53 + pg.width, x, y)
   x += 9
  end
  
  
 end

end
__gfx__
0000000082222220525252508222222082828220888888200222222087777778e222222052525250e2222220e2eee220eeeeee2002222220e777777e00000000
000000002282822025858525222222202888882028888820222222227787877822eee22025e5e525222222202eeeee202eeeee202222222277eee77e00000000
00700700288888205858585022222220288888202288822022822822788888782eeeee205e5e5e50222222202eeeee202eeeee2022e22e227eeeee7e00000000
00077000288888202585852528828820228882202228222022822822788888782eeeee2025e5e5252eeeee202eeeee2022eee22022e22e227eeeee7e00000000
00077000228882205258525088888880222822202222222022222222778887782eeeee205e5e5e50eeeeeee022eee22022222220222222227eeeee7e00000000
007007002228222025252525288888202222222022222220228888227778777822eee22025e5e525eeeeeee0222222202222222022eeee2277eee77e00000000
000000002222222052525250228882202222222022222220222222227777777822222220525252502eeeee202222222022222220222222227777777e00000000
0000000000000000050505050000000000000000000000000222222088888888000000000505050500000000000000000000000002222220eeeeeeee00000000
ddddddddc111111051515150c1111110c11c1110c1ccc11001111110c777777ca999999059595950a9999990aaaaaa90aaaaaa9009999990a777777adddddddd
dddddddd111c1110151515151111111011ccc1101ccccc1011111111777c777c9aaaaa9095a5a595999999909aaaaa9099aaa990999999997aaaaa7adddddddd
dd00000d11ccc110515c5150111111101ccccc1011ccc11011c11c1177ccc77c9aaaaa905a5a5a509999999099aaa99099aaa99099a99a997aaaaa7adddddddd
dd07770d1ccccc1015c5c5151111111011ccc110111c111011c11c117ccccc7c99aaa99095a5a5959999999099aaa990999a999099a99a9977aaa77ad17dd17d
dd07000d11ccc110515c51501ccccc10111c1110111111101111111177ccc77c99aaa990595a5950aaaaaaa0999a9990999999909999999977aaa77ad77dd77d
dd070ddd111c111015151515ccccccc0111111101111111011cccc11777c777c999a9990959595959aaaaa90999999909999999099aaaa99777a777adddddddd
dd000ddd11111110515151501ccccc101111111011111110111111117777777c999999905959595099aaa9909999999099999990999999997777777adddddddd
dddddddd000000000505050500000000000000000000000001111110cccccccc000000000505050500000000000000000000000009999990aaaaaaaadddddddd
ddddddddb333333053535350b3333330b33b3330b3bbb33003333330b777777b65555550050505006555555065565550655655500555555067777776dddddddd
dddddddd333b3330353535353333333033bbb33033bbb33033333333777b777b55565550505050505555555055565550555655505555555577767776dddddddd
d00000dd33bbb330535b53503333333033bbb3303bbbbb3033b33b3377bbb77b55565550050605005555555055565550555555505565565577767776dddddddd
d07770dd33bbb33035b5b535333333303bbbbb303bbbbb3033b33b3377bbb77b55565550505050505566655055555550555655505565565577767776dddddddd
d00700dd3bbbbb305b5b5b503bbbbb303bbbbb3033333330333333337bbbbb7b55555550050505005566655055565550555555505555555577777776d55dd55d
dd070ddd3bbbbb3035b5b535bbbbbbb0333333303333333033bbbb337bbbbb7b55565550505050505555555055555550555555505566665577767776dddddddd
dd000ddd3333333053535350bbbbbbb03333333033333330333333337777777b55555550050505005566655055555550555555505555555577777776dddddddd
dddddddd000000000505050500000000000000000000000003333330bbbbbbbb00000000000000000000000000000000000000000555555066666666dddddddd
cccccccc94444440545454509444444099949940999999400444444097777779dddddddddddddddddddddddddddddddd0000000d000000005555555555555555
cccccccc49949940459595454444444049999940449994404444444479979979ddddddddd00000dd0000000d0000000d0101010d000000005000000557777775
ccc76ccc499999405959595044444440449994404999994044944944799999790000000dd01010dd0101010d0101010d0000000d000000005050050557577575
cc7665cc449994404595954599949990499999404994994044944944779997790101010dd00000dd0000000d0000000d5010105d000000005050050557577575
cc6655cc499999405959595099999990499499404444444044444444799999790000000dd01010dd5010105d0101010d0000000d000000005000000557777775
ccc55ccc499499404595954599999990444444404444444044999944799799795555555dd00000ddd00000dd0000000d0101010d000000005055550557555575
cccccccc44444440545454509994999044444440444444404444444477777779ddddddddd55555ddd55555dd5555555d0000000d000000005000000557777775
cccccccc00000000050505050000000000000000000000000444444099999999dddddddddddddddddddddddddddddddd5555555d000000005555555555555555
dddddddddd7333337d7dddddddddddddd05000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
dddddddddd733333070dddddddddddddd05000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
dddddddddd733333707ddddddd000000d05000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
dddd7777dd0733330d0dddddd0555555d05555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ddd73333ddd07777ddddddddd0500000dd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
dd733333dddd0000ddddddddd0500000dddddddd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
dd733333ddddddddddddddddd0500000dddddddd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
dd733333ddddddddddddddddd0500000dddddddd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
57777777777777777777777777777777777777777777777777777555555555555555555555577777777777777777777777777777777777777777777777777775
57111111111111111111111111111111111111111111111111117555555555555555555555571111111111111111111111111111111111111111111111111175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
571dddddddddddddddddddddddddddddddddddddddddddddddd17555555555555555555555571dddddddddddddddddddddddddddddddddddddddddddddddd175
57182222220e2222220ddddddddddddddddc1111110944444401755555555555555555555557182222220e2222220ddddddddddddddddc111111094444440175
5712282822022eee220dddddddddddddddd111c111049949940175555555555555555555555712282822022eee220dddddddddddddddd111c111049949940175
571288888202eeeee20dddddddddddddddd11ccc1104999994017555555555555555555555571288888202eeeee20dddddddddddddddd11ccc11049999940175
571288888202eeeee20dddddddddddddddd1ccccc104499944017555555555555555555555571288888202eeeee20dddddddddddddddd1ccccc1044999440175
571228882202eeeee20dddddddddddddddd11ccc1104999994017555555555555555555555571228882202eeeee20dddddddddddddddd11ccc11049999940175
5712228222022eee220dddddddddddddddd111c111049949940175555555555555555555555712228222022eee220dddddddddddddddd111c111049949940175
500000220000022200000dddddddddddddd111111104444444017555555555555555555555500000220000022200000dddddddddddddd1111111044444440175
507770000777000007770dddddddddddddd000000000000000017555555555555555555555507770000777000007770dddddddddddddd0000000000000000175
507000990070033300070dddddddddddddd82222220b333333017555555555555555555555507000990070033300070dddddddddddddd82222220b3333330175
5070aaaaa07033b333070dddddddddddddd22828220333b3330175555555555555555555555070aaaaa07033b333070dddddddddddddd22828220333b3330175
5000aaaaa0003bbb33000dddddddddddddd2888882033bbb330175555555555555555555555000aaaaa0003bbb33000dddddddddddddd2888882033bbb330175
57199aaa99033bbb330dddddddddddddddd2888882033bbb3301755555555555555555555557199aaa99033bbb330dddddddddddddddd2888882033bbb330175
50009aaa9000bbbbb3000dddddddddddddd228882203bbbbb301755555555555555555555550009aaa9000bbbbb3000dddddddddddddd228882203bbbbb30175
507099a99070bbbbb3070dddddddddddddd222822203bbbbb3017555555555555555555555507099a99070bbbbb3070dddddddddddddd222822203bbbbb30175
507000990070033300070dddddddddddddd222222203333333017555555555555555555555507000990070033300070dddddddddddddd2222222033333330175
507770000777000007770dddddddddddddd000000000000000017555555555555555555555507770000777000007770dddddddddddddd0000000000000000175
500000220000099900000dddddddddddddde2222220e222222017555555555555555555555500000220000099900000dddddddddddddde2222220e2222220175
57122eee2209aaaaa90dddddddddddddddd22eee22022eee2201755555555555555555555557122eee2209aaaaa90dddddddddddddddd22eee22022eee220175
5712eeeee209aaaaa90dddddddddddddddd2eeeee202eeeee20175555555555555555555555712eeeee209aaaaa90dddddddddddddddd2eeeee202eeeee20175
5712eeeee2099aaa990dddddddddddddddd2eeeee202eeeee20175555555555555555555555712eeeee2099aaa990dddddddddddddddd2eeeee202eeeee20175
5712eeeee2099aaa990dddddddddddddddd2eeeee202eeeee20175555555555555555555555712eeeee2099aaa990dddddddddddddddd2eeeee202eeeee20175
57122eee220999a9990dddddddddddddddd22eee22022eee2201755555555555555555555557122eee220999a9990dddddddddddddddd22eee22022eee220175
5712222222099999990dddddddddddddddd2222222022222220175555555555555555555555712222222099999990dddddddddddddddd2222222022222220175
5710000000000000000dddddddddddddddd0000000000000000175555555555555555555555710000000000000000dddddddddddddddd0000000000000000175
571a9999990a9999990ddddddddddddddddb3333330b333333017555555555555555555555571a9999990a9999990ddddddddddddddddb3333330b3333330175
5719aaaaa909aaaaa90dddddddddddddddd333b3330333b3330175555555555555555555555719aaaaa909aaaaa90dddddddddddddddd333b3330333b3330175
5719aaaaa909aaaaa90dddddddddddddddd33bbb33033bbb330175555555555555555555555719aaaaa909aaaaa90dddddddddddddddd33bbb33033bbb330175
57199aaa99099aaa990dddddddddddddddd33bbb33033bbb3301755555555555555555555557199aaa99099aaa990dddddddddddddddd33bbb33033bbb330175
57199aaa99099aaa990dddddddddddddddd3bbbbb303bbbbb301755555555555555555555557199aaa99099aaa990dddddddddddddddd3bbbbb303bbbbb30175
571999a9990999a9990dddddddddddddddd3bbbbb303bbbbb3017555555555555555555555571999a9990999a9990dddddddddddddddd3bbbbb303bbbbb30175
5719999999099999990dddddddddddddddd3333333033333330175555555555555555555555719999999099999990dddddddddddddddd3333333033333330175
5710000000000000000dddddddddddddddd0000000000000000175555555555555555555555710000000000000000dddddddddddddddd0000000000000000175
571b3333330e222222082222220b3333330c1111110b333333017555555555555555555555571b3333330e222222082222220b3333330c1111110b3333330175
571333b333022eee22022828220333b3330111c1110333b333017555555555555555555555571333b333022eee22022828220333b3330111c1110333b3330175
57133bbb3302eeeee202888882033bbb33011ccc11033bbb3301755555555555555555555557133bbb3302eeeee202888882033bbb33011ccc11033bbb330175
57133bbb3302eeeee202888882033bbb3301ccccc1033bbb3301755555555555555555555557133bbb3302eeeee202888882033bbb3301ccccc1033bbb330175
5713bbbbb302eeeee20228882203bbbbb3011ccc1103bbbbb30175555555555555555555555713bbbbb302eeeee20228882203bbbbb3011ccc1103bbbbb30175
5713bbbbb3022eee220222822203bbbbb30111c11103bbbbb30175555555555555555555555713bbbbb3022eee220222822203bbbbb30111c11103bbbbb30175
57133333330222222202222222033333330111111103333333017555555555555555555555571333333302222222022222220333333301111111033333330175
57100000000000000000000000000000000000000000000000017555555555555555555555571000000000000000000000000000000000000000000000000175
571c11111109444444082222220c1111110e22222209444444017555555555555555555555571c11111109444444082222220c1111110e222222094444440175
571111c11104994994022828220111c111022eee2204994994017555555555555555555555571111c11104994994022828220111c111022eee22049949940175
57111ccc110499999402888882011ccc1102eeeee20499999401755555555555555555555557111ccc110499999402888882011ccc1102eeeee2049999940175
5711ccccc1044999440288888201ccccc102eeeee2044999440175555555555555555555555711ccccc1044999440288888201ccccc102eeeee2044999440175
57111ccc110499999402288822011ccc1102eeeee20499999401755555555555555555555557111ccc110499999402288822011ccc1102eeeee2049999940175
571111c11104994994022282220111c111022eee2204994994017555555555555555555555571111c11104994994022282220111c111022eee22049949940175
57111111110444444402222222011111110222222204444444017555555555555555555555571111111104444444022222220111111102222222044444440175
57100000000000000000000000000000000000000000000000017555555555555555555555571000000000000000000000000000000000000000000000000175
571a9999990a999999094444440c1111110c1111110b333333017555555555555555555555571a9999990a999999094444440c1111110c1111110b3333330175
5719aaaaa909aaaaa9049949940111c1110111c1110333b3330175555555555555555555555719aaaaa909aaaaa9049949940111c1110111c1110333b3330175
5719aaaaa909aaaaa904999994011ccc11011ccc11033bbb330175555555555555555555555719aaaaa909aaaaa904999994011ccc11011ccc11033bbb330175
57199aaa99099aaa990449994401ccccc101ccccc1033bbb3301755555555555555555555557199aaa99099aaa990449994401ccccc101ccccc1033bbb330175
57199aaa99099aaa9904999994011ccc11011ccc1103bbbbb301755555555555555555555557199aaa99099aaa9904999994011ccc11011ccc1103bbbbb30175
571999a9990999a999049949940111c1110111c11103bbbbb3017555555555555555555555571999a9990999a999049949940111c1110111c11103bbbbb30175
57199999990999999904444444011111110111111103333333017555555555555555555555571999999909999999044444440111111101111111033333330175
57100000000000000000000000000000000000000000000000017555555555555555555555571000000000000000000000000000000000000000000000000175
57159595950525252505353535059595950545454505353535017555555555555555555555571595959505252525053535350595959505454545053535350175
57195a5a595258585253535353595a5a59545959545353535351755555555555555555555557195a5a595258585253535353595a5a5954595954535353535175
5715a5a5a5058585850535b53505a5a5a5059595950535b5350175555555555555555555555715a5a5a5058585850535b53505a5a5a5059595950535b5350175
57195a5a5952585852535b5b53595a5a5954595954535b5b5351755555555555555555555557195a5a5952585852535b5b53595a5a5954595954535b5b535175

__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000012107000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000012131000039000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000110131000039000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00003107170000383a3800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000171701000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000120818000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000600000775008750097500a7500b7500c7500d7500e7500f750107501175012750137501475015750167501775018750197501a7501b7501c7501d7501e7501f75020750217502275023750247502575026750
0002000007610096100c6100461018600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000700000302002000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100002901000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
