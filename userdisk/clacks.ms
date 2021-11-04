// 3D coordinate system:
//   x: blocks right of center
//   y: blocks up from bottom
//   z: blocks back in depth

import "qa"
import "listUtil"
import "mathUtil"
import "starfield"

//bgm = file.loadSound("sounds/retro-arcade.ogg")
if not globals.hasIndex("bgm") or not (bgm isa Sound) then
	bgm = file.loadSound("sounds/chemical-beat.ogg")
end if
bgm.loop = true
bgmEnd = file.loadSound("sounds/bgm-end.wav")

kBlockWidth = 64
kBlockHeight = 16

img = file.loadImage("pics/blocks.png")
h = img.height/3
blockFrames = []  // first index: column (0-2); second index: anim frame
for col in range(0,2)
	blockFrames.push []
	for i in range(0,3)
		blockFrames[col].push img.getImage(i*171,h*col,171,h)
	end for
end for

img = file.loadImage("pics/catcher.png")
h = img.height/3
catcherFrames = []  // first index: column (0-2); second index: state
for col in range(0,2)
	catcherFrames.push []
	for i in range(0,8)
		catcherFrames[col].push img.getImage(i*171,h*col,171,h)
	end for
end for

img = file.loadImage("pics/catchLights.png")
h = img.height/6
lightFrames = []
for i in range(0,5)
	lightFrames.push img.getImage(0, h*i, img.width, h)
end for

guitarPool = []
for i in range(9)
	guitarPool.push file.loadSound("/sys/sounds/guitarPluckC4.wav")
end for

clackPool = []
for i in range(7)
	clackPool.push file.loadSound("sounds/clack.wav")
end for

playClack = function(block)
	snd = clackPool.pull
	persFactor = 10 / (10 + block.z)
	pan = (block.col - 2) * 0.4 * persFactor
	vol = 0.4 * persFactor
	snd.play vol, pan
	clackPool.push snd
end function

// Convert an [x,y,z] point in 3D space
// to an [x,y] screen position.
project = function(point3d)
	qa.assert point3d.len == 3
	x = point3d[0]
	y = point3d[1]
	z = point3d[2]
	persFactor = 10 / (10 + z)
	return [480 + kBlockWidth * x * persFactor,
	50 + kBlockHeight * y + 400*(1-persFactor)]
end function

line3d = function(p0, p1)
	a = project(p0)
	b = project(p1)
	gfx.line a[0],a[1], b[0],b[1]
end function

drawPoly3d = function(points3d, color=null, penSize=1)
	points2d = []
	for p in points3d
		points2d.push project(p)
	end for
	gfx.drawPoly points2d, color, penSize
end function

fillPoly3d = function(points3d)
	points2d = []
	for p in points3d
		points2d.push project(p)
	end for
	gfx.fillPoly points2d
end function

trackRow = 11
drawTrack = function()
	// Draw the track (at y=11, z>1)
	y = trackRow
	for z in range (2, 21)
		for x in range(-2, 2)
			gfx.color = color.lerp(color.white, color.gray, z/21)
			drawPoly3d [[x-0.5,y,z],[x-0.5,y,z+1],[x+0.5,y,z+1],[x+0.5,y,z]]
		end for
	end for
end function

drawBin = function()
	// Draw the bin, as a sprite so that it sorts properly
	// with blocks falling above or into it
	binSprite = new Sprite
	binSprite.image = file.loadImage("pics/bin.png")
	binSprite.x = 480; binSprite.y = 107
	binSprite.tint = "#CCCCCC"
	binSprite.update = null
	binSprite.sortOrder = -1000
	display(4).sprites.push binSprite
end function

// sprite was created with:
drawBinManually = function()
	// Draw the sides of the bin
	y = 0; z = -0.05
	gfx.color = color.white
	for x in [-2.55, 2.55]
		for y in range(0, 4)
			drawPoly3d [[x,y,z],[x,y+1,z],[x,y+1,z+1.1],[x,y,z+1.1]]
		end for
	end for
	
	// Also draw the bottom of the bin
	y = 0
	for x in range(-2, 2)
		x0 = x - 0.5 - 0.05 * (x == -2)
		x1 = x + 0.5 + 0.05 * (x == 2)
		drawPoly3d [[x0,y,z],[x0,y,z+1.1],[x1,y,z+1.1],[x1,y,z]]
	end for
end function

// block states:
kWalking = "kWalking"
kFalling = "kFalling"
kCaught = "kCaught"
kBin = "kBin"

// base class for any block-ish sprite positioned in 3D
ThreeDSprite = new Sprite
ThreeDSprite.scale = 0.5
ThreeDSprite.col = 0
ThreeDSprite.row = 0
ThreeDSprite.z = 1
ThreeDSprite.frames = null // 2D array, by [column][variant]
ThreeDSprite.selectImage = function(variant)
	self.image = self.frames[abs(round(self.col)-2)][variant]
end function
ThreeDSprite.place = function(x, y, z, sort=true)
	self.col = x  // note: these use x=0 to mean leftmost column
	self.row = y
	self.z = z
	pos = project([x-2,y,z])
	zfactor = 10 / (10 + z)
	s = ThreeDSprite.scale * zfactor
	if x > 2 then self.scale = [-s,s] else self.scale = s
	self.x = pos[0] + [4,2,0,-2,-4][x] * zfactor
	self.y = pos[1] + 53 * zfactor
	self.sortOrder = -z*1000 + y*10 - abs(x-2)
	if sort then display(4).sprites.sort "sortOrder"
end function
ThreeDSprite.update = null

// Catcher: catches the blocks (up to 5), and then ejects them.
catcher = new ThreeDSprite
catcher.frames = catcherFrames
catcher.targetCol = 2
catcher.place catcher.targetCol, trackRow-1, 1
catcher.selectImage 0
catcher.prevInput = 0
catcher.blocks = []
catcher.ejectTime = -999
catcher.lights = new Sprite
catcher.lights.update = null

catcher.reset = function()
	self.blocks = []
	self.ejectTime = -999	
	catcher.targetCol = 2
	self.place self.targetCol, trackRow-1, 1
	self.updateSprites
end function

catcher.canCatch = function()
	return self.blocks.len < 5
end function

catcher.catchBlock = function(block)
	self.row = self.row - 1
	self.blocks.push block
	for i in self.blocks.indexes
		self.blocks[i].row = self.row + i + 1
	end for
	self.updateSprites
	addToScore self.blocks.len
end function

catcher.ejectBlock = function()
	self.ejectTime = time
	if not self.blocks then return
	col = round(self.col)
	if bin[col].len >= 5 then return  // bin full
	// move catcher and all its blocks up 1 row
	self.row = self.row + 1
	for i in self.blocks.indexes
		self.blocks[i].row = self.row + i + 1
	end for
	self.updateSprites
	// pop off the top block, and drop it into the bin
	b = self.blocks.pop
	b.col = col
	b.state = kWalking
	b.nextFrameTime = 0  // (ensures it does not get immediately caught!)
	b.targetRow = bin[col].len
	bin[col].push b
end function

catcher.updateSprites = function()
	self.place self.col, self.row, 1	
	self.lights.x = self.x + (self.col-2) * 2
	self.lights.y = self.y - 40
	self.lights.image = lightFrames[5 - self.blocks.len]
	self.lights.sortOrder = self.sortOrder + 1
	
	for b in self.blocks
		b.place self.col, b.row, 1
		b.selectImage 2
	end for	
end function

catcher.update = function()
	// works with gamepad, but sometimes misses an input:
	//inp = round(key.axis("Horizontal"))
	// keyboard only, but never misses:
	inp = 0
	if key.available then
		k = key.get.code  // 17: left; 18: right
		inp = (k == 18) - (k == 17)
		if k == 19 or k == 32 then self.ejectBlock
	end if
	
	if inp != self.prevInput then
		self.targetCol = mathUtil.clamp(self.targetCol + inp, 0, 4)
		self.prevInput = inp
	end if
	if self.col != self.targetCol then
		self.col = mathUtil.moveTowards(self.col, self.targetCol, 0.2)
		self.updateSprites
	end if
	
	t = time - self.ejectTime
	if t > 0.2 then
		variant = 0
	else if t > 0.15  or t < 0.05 then
		variant = 1
	else
		variant = 2		
	end if
	self.selectImage variant
	
end function

catcher.updateSprites

// Block: represents any of the animated/falling game blocks
Block = new ThreeDSprite
Block.state = kWalking
Block.frameNum = 2
Block.nextFrameTime = 0
Block.frames = blockFrames

Block.updateWalk = function()
	if time < self.nextFrameTime then return
	self.frameNum = self.frameNum + 1
	if self.frameNum > 3 then
		self.z = self.z - 1
		self.place self.col, self.row, self.z
		self.frameNum = 0
	end if
	self.selectImage self.frameNum
	
	if self.frameNum == 0 then playClack self	
	
	dtime = 0.1
	if self.frameNum == 2 then dtime = 0.4
	if hurry then dtime = dtime / 10
	self.nextFrameTime = time + dtime
end function

Block.updateFall = function()
	self.row = self.row - 0.5
	if self.z == 0 then
		// Land when we hit our target row
		if self.row < self.targetRow then
			self.row = self.targetRow
			self.state = kBin
			self.selectImage 2  // make sure it's laying flat!
			checkForSets
		end if
	end if
	self.place self.col, self.row, self.z
	if self.y < -20 then
		// fell off the bottom of the screen
		loseLife
		display(4).sprites.removeVal self
	end if
end function

Block.update = function()
	if self.state == kWalking then
		self.updateWalk
		if self.z == 1 and self.frameNum == 2 then
			// End of the row!  Either we're caught, or we fall.
			if self.col == round(catcher.col) and catcher.canCatch then
				self.state = kCaught
				catcher.catchBlock self
			else
				self.state = kFalling
			end if
		else if self.z == 0 and self.frameNum == 2 then
			// falling into the bin
			self.state = kFalling
		end if
	else if self.state == kFalling then
		self.updateFall
	end if
end function

// Bin: a 2D list-of-lists indexed by [column][row]
// (list within a column is only as long as there are blocks)
bin = [[], [], [], [], []]
notes = [
[48, 51, 54, 57, 60],
[54, 57, 60, 63, 66],
[60, 63, 66, 69, 72],
[66, 69, 72, 75, 78],
[72, 75, 78, 81, 84]]

clearSet = function(positions)
	blocks = []
	for pos in positions
		blocks.push bin[pos[0]][pos[1]]		
	end for
	notesToPlay = []
	for posIndex in positions.indexes
		pos = positions[posIndex]
		col = pos[0]
		row = pos[1]
		b = blocks[posIndex]
		bincol = bin[pos[0]]
		bincol.removeVal b
		for i in bincol.indexes
			b = bincol[i]
			if b.targetRow != i then
				b.state = kFalling
				b.targetRow = i
			end if
		end for
		// push the note number, and column (X position)
		notesToPlay.push [notes[row][col], col]
	end for
	nextNoteTime = time
	setColor = blocks[0].tint
	// lerp to white
	for i in range(0,100,4)
		for b in blocks
			b.tint = color.lerp(setColor, color.white, i/100)
		end for
		if notesToPlay and time > nextNoteTime then
			noteAndCol = notesToPlay.pull
			freq = noteFreq(noteAndCol[0])/noteFreq(60)
			pan = (noteAndCol[1] - 2) * 0.4
			guitarPool[0].play 1, pan, freq
			nextNoteTime = time + 0.1
		end if
		yield
	end for
	// lerp to clear
	clearTint = blocks[0].tint[:7] + "00"
	for i in range(0,100,4)
		for b in blocks
			b.tint = color.lerp(color.white, clearTint, i/100)
		end for
		yield
	end for
	for b in blocks
		display(4).sprites.removeVal b
	end for
end function

//============================================================
// 3-or-more-in-a-row detection code
//============================================================

colorAtColRow = function(col, row)
	if bin[col].len <= row then return ""
	if bin[col][row].state != kBin then return ""
	return bin[col][row].tint
end function

checkSetsVertical = function()
	result = {}
	for col in range(0,4)
		if bin[col].len < 3 then continue
		setColor = colorAtColRow(col, 0); setStart=0; setEnd=0
		for row in range(1, bin[col].len-1)
			c = colorAtColRow(col, row)
			if c == setColor then
				setEnd = row
			else
				if setEnd - setStart >= 2 then break
				setColor = c; setStart=row; setEnd=row
			end if
		end for
		if setEnd - setStart >= 2 and setColor then
			for row in range(setStart, setEnd)
				result.push [col, row]
			end for
			addToScore 100
			return result
		end if
	end for
	return result
end function

checkSetsHorizontal = function()
	result = {}
	for row in range(0, 5)
		setColor = colorAtColRow(0, row); setStart=0; setEnd=0
		for col in range(1, 4)
			c = colorAtColRow(col, row)
			if c == setColor then
				setEnd = col
			else
				if setEnd - setStart >= 2 then break
				setColor = c; setStart=col; setEnd=col
			end if
		end for
		if setEnd - setStart >= 2 and setColor then
			for col in range(setStart, setEnd)
				result.push [col, row]
			end for
			addToScore 100 + 50 * 2^(result.len-2)  // 200, 300, 500
			return result
		end if
	end for
	return result	
end function

checkSetsDiagonalUp = function()
	result = {}
	for row in range(0, 2)
		for col in range(0, 2)
			setColor = colorAtColRow(col, row)
			setStart=0; setEnd=0
			for i in range(1,4)
				if row+i>4 or col+i>4 then break
				c = colorAtColRow(col+i, row+i)
				if c == setColor then
					setEnd = i
				else
					if setEnd - setStart >= 2 then break
					setColor = c; setStart=i; setEnd=i
				end if
			end for
			if setEnd - setStart >= 2 and setColor then
				for i in range(setStart, setEnd)
					result.push [col+i, row+i]
				end for
				addToScore 200 + 75 * 2^(result.len-2)  // 350, 500, 800
				return result
			end if
		end for
	end for
	return result
end function

checkSetsDiagonalDown = function()
	result = {}
	for row in range(2, 4)
		for col in range(0, 2)
			setColor = colorAtColRow(col, row)
			setStart=0; setEnd=0
			for i in range(1,4)
				if row-i<0 or col+i>4 then break
				c = colorAtColRow(col+i, row-i)
				if c == setColor then
					setEnd = i
				else
					if setEnd - setStart >= 2 then break
					setColor = c; setStart=i; setEnd=i
				end if
			end for
			if setEnd - setStart >= 2 and setColor then
				for i in range(setStart, setEnd)
					result.push [col+i, row-i]
				end for
				addToScore 200 + 75 * 2^(result.len-2)  // 350, 500, 800
				return result
			end if
		end for
	end for
	return result
end function

checkForSets = function()
	blocksToClear = checkSetsVertical +
	checkSetsHorizontal +
	checkSetsDiagonalUp +
	checkSetsDiagonalDown
	if blocksToClear then clearSet blocksToClear.indexes
end function

//============================================================
// Display code (score, etc.)
//============================================================
score = 0
lives = 3
drawScore = function()
	overlayGfx.fillRect 790,600,150,40, color.clear
	s = ("00000" + score)[-6:]
	overlayGfx.print s,800, 600, color.yellow, "large"
end function

addToScore = function(points)
	globals.score = score + points
	drawScore
end function

Heart = new Sprite
Heart.fullImage = file.loadImage("pics/heart-full.png")
Heart.halfImage = file.loadImage("pics/heart-half.png")
Heart.emptyImage = file.loadImage("pics/heart-empty.png")
Heart.sortOrder = 1000
Heart.throbStartTime = 0
Heart.throbsLeft = 0
Heart.update = function()
	if self.throbsLeft == 0 then return
	t = (time - self.throbStartTime) / 0.5
	if t > 1 then
		t = 1
		self.throbsLeft = self.throbsLeft - 1
		self.throbStartTime = time
	end if
	if self.image == Heart.emptyImage then s = -1 else s = 1
	self.scale = 1 + 0.25 * (cos(t*pi/2)) * s
end function
Heart.throb = function(count)
	self.throbsLeft = count
	self.throbStartTime = time
end function

prepareHearts = function()
	globals.hearts = []
	for i in range(0,2)
		hearts.push new Heart
		hearts[i].x = 40 + 40*i
		hearts[i].y = 610
		display(4).sprites.push hearts[i]
	end for
end function

updateHearts = function()
	left = lives
	for i in range(0,2)
		if left > 0.9 then
			hearts[i].image = Heart.fullImage
		else if left > 0.4 then
			hearts[i].image = Heart.halfImage
		else
			hearts[i].image = Heart.emptyImage
		end if
		left = left - 1
	end for
	if lives > 1 and hearts[0].throbsLeft < 0 then
		hearts[0].throbsLeft = 1
	end if
end function
updateHearts

loseLife = function()
	globals.lives = lives - 1
	hearts[floor(lives)].throb 3
	if lives <= 1 then hearts[0].throbsLeft = -1  // (throb indefinitely)
	updateHearts
end function

level = 1
blocksLeft = 0
blocksInLevel = 30
drawLevel = function()
	overlayGfx.fillRect 30, 560, 100, 20, color.clear
	overlayGfx.drawRect 28, 558, 104, 24, color.blue, 2
	s = "LEVEL " + level
	overlayGfx.print s, 80 - s.len*4.5, 564, color.yellow, "small"
end function
progressBar = new Sprite
progressBar.image = file.loadImage("pics/gradientBar.png")
progressBar.tint = "#8888FF"
progressBar.y = 570
progressBar.x = 50
progressBar.sortOrder = 1000
progressBar.update = null
updateProgress = function()
	prog = 1 - blocksLeft / blocksInLevel  // progress
	if prog > 1 then prog = 1
	w = 100 * prog  // (progress bar width)
	pb = progressBar
	pb.x = 30 + w/2
	pb.scale = [w/pb.image.width, 20/pb.image.height]
end function

//============================================================

addBlock = function(x, y, z=0)
	b = new Block
	b.selectImage 2
	display(4).sprites.push b
	b.place x, y, z
	b.tint = blockColors.any
	b.nextFrameTime = time + rnd * 0.5
	return b
end function

startNextLevel = function()
	globals.level = level + 1
	globals.blocksInLevel = 10 + (level-1) * 5
	globals.blocksLeft = blocksInLevel
	globals.blockColors = ["#FFAAAA", "#AAFFAA", "#AAAAFF", 
	"#FFFFAA", "#FFAAFF", "#AAFFFF", 
	color.orange, color.silver, color.pink]
	maxColors = 6 + ceil((level-2)/3)
	if blockColors.len > maxColors then 
		globals.blockColors = blockColors[:maxColors]
	end if
	drawLevel
	updateProgress
	if lives < 3 then
		globals.lives = lives + 0.5
		updateHearts
	end if
	blocksToClear = []
	if rnd < 0.5 then
		// clear a random column
		col = floor(rnd * 5)
		for i in range(4)
			if colorAtColRow(col,i) then blocksToClear.push [col,i]
		end for
	else
		// clear a random row
		row = floor(rnd * 3)
		for i in range(4)
			if colorAtColRow(i,row) then blocksToClear.push [i,row]
		end for
	end if
	if blocksToClear then clearSet blocksToClear
end function

pickNextBlockInterval = function()
	// average time decreases as we approach the end of the level,
	// and also with higher levels
	avg = 1 + 1/level + 2 * blocksLeft/blocksInLevel
	return avg + (rnd-0.5) * avg/2
end function

waitForEnterKey = function()
	while true
		if key.available then
			k = key.get.code
			if k == 3 or k == 10 or k == 13 then return
		end if
		starfield.update
		yield
	end while
end function

// main loop
while true
	Sound.stopAll
	clear
	gfx.drawImage file.loadImage("pics/TitleScreen.jpg")
	waitForEnterKey
	gfx.clear color.clear
	
	// initial setup
	starfield.setup
	display(2).mode = displayMode.pixel
	overlayGfx = display(2)
	overlayGfx.clear color.clear
	drawTrack
	drawBin
	bin = [[], [], [], [], []]
	catcher.reset
	display(4).sprites.push catcher
	display(4).sprites.push catcher.lights
	lives = 3; prepareHearts; updateHearts
	display(4).sprites.push progressBar
	level = 0; startNextLevel
	score = 0; drawScore
	bgm.play 0.25
	
	// main loop
	nextBlockTime = 0
	while lives > 0 or hearts[0].throbsLeft > 0
		hurry = key.pressed("down")
		if hurry then nextBlockTime = nextBlockTime - 0.05
		anyMoving = false
		for b in display(4).sprites
			b.update
			if b isa Block and b.state != kBin then anyMoving = true
		end for
		if time > nextBlockTime then
			if blocksLeft > 0 then
				// add a new block!
				addBlock floor(rnd * 5), trackRow, 20
				nextBlockTime = time + pickNextBlockInterval
				blocksLeft = blocksLeft - 1
				updateProgress
			else if not anyMoving and not catcher.blocks then
				// next level!
				startNextLevel
			end if
		end if
		if key.pressed("c") then
			blocksLeft = 0 // cheat!
			updateProgress
		end if
		if key.pressed("escape") then break
		starfield.update
		yield
	end while
	bgm.stop
	bgmEnd.play
	img = file.loadImage("pics/GameOver.png")
	overlayGfx.drawImage img, 480-img.width/2, 420-img.height/2
	waitForEnterKey
end while
