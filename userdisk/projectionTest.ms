// 3D coordinate system:
//   x: blocks right of center
//   y: blocks up from bottom
//   z: blocks back in depth

import "qa"
import "listUtil"

kBlockWidth = 64
kBlockHeight = 16

img = file.loadImage("pics/blocks.png")
h = img.height/3
frames = []  // first index: column (0-2); second index: anim frame
for col in range(0,2)
	frames.push []
	for i in range(0,3)
		frames[col].push img.getImage(i*171,h*col,171,h)
	end for
end for

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

drawBlock = function(x, y, z)
	// top
	gfx.color = "#CCCCCC"
	fillPoly3d [[x-0.5,y+1,0],[x-0.5,y+1,1],[x+0.5,y+1,1],[x+0.5,y+1,0]]
	
	// front	
	gfx.color = "#F0F0F0"
	fillPoly3d [[x-0.5,y,0],[x-0.5,y+1,0],[x+0.5,y+1,0],[x+0.5,y+0,0]]
	gfx.color = color.white
	drawPoly3d [[x-0.5,y,0],[x-0.5,y+1,0],[x+0.5,y+1,0],[x+0.5,y+0,0]]
	
	gfx.color = "#AAAAAA"
	if x > 0 then
		// left side
		fillPoly3d [[x-0.5,y,0],[x-0.5,y,1],[x-0.5,y+1,1],[x-0.5,y+1,0]]
		gfx.color = color.white
		line3d [x-0.5,y+1,0], [x-0.5,y+1,1]
	else if x < 0 then
		// right side
		fillPoly3d [[x+0.5,y,0],[x+0.5,y,1],[x+0.5,y+1,1],[x+0.5,y+1,0]]
		gfx.color = color.white
		line3d [x+0.5,y+1,0], [x+0.5,y+1,1]
	end if
	
	// outline in black
	pts = [[x-0.5,y,0],[x+0.5,y,0]]
	if x >= 0 then
		pts = pts + [[x+0.5,y+1,0],[x+0.5,y+1,1]]
	else
		pts = pts + [[x+0.5,y,1],[x+0.5,y+1,1]]
	end if
	pts.push [x-0.5,y+1,1]
	if x <= 0 then
		pts.push [x-0.5,y+1,0]
	else
		pts.push [x-0.5,y,1]
	end if
	pts.push [x-0.5,y,0]
	drawPoly3d pts, color.black, 2
end function

clear

// Draw the track (at y=11, z>1)
trackRow = 11
y = trackRow
for z in range (2, 21)
	for x in range(-2, 2)
		gfx.color = color.lerp(color.white, color.gray, z/21)
		drawPoly3d [[x-0.5,y,z],[x-0.5,y,z+1],[x+0.5,y,z+1],[x+0.5,y,z]]
	end for
end for

// draw a block
//drawBlock 1, 14, 0
//drawBlock -2, 14, 0

// let's try drawing blocks with sprites
Block = new Sprite
Block.scale = 0.5
Block.sortOrder = 0
Block.col = 0
Block.row = trackRow
Block.z = 20
Block.frameNum = 2
Block.nextFrameTime = 0
Block.place = function(x, y, z, sort=true)
	self.col = x
	self.row = y
	self.z = z
	pos = project([x,y,z])
	zfactor = 10 / (10 + z)
	s = Block.scale * zfactor
	if x > 0 then self.scale = [-s,s] else self.scale = s
	self.x = pos[0] + [4,2,0,-2,-4][x+2] * zfactor
	self.y = pos[1] + 53 * zfactor
	self.sortOrder = -z*1000 + y*10 - abs(x)
	if sort then display(4).sprites.sort "sortOrder"
end function
Block.update = function()
	if self.z < 2 and self.frameNum == 2 then return
	if self.nextFrameTime == 0 then return
	if time < self.nextFrameTime then return
	self.frameNum = self.frameNum + 1
	if self.frameNum > 3 then
		self.z = self.z - 1
		self.place self.col, self.row, self.z
		self.frameNum = 0
	end if
	self.image = frames[abs(round(self.col))][self.frameNum]
	if self.frameNum == 2 then
		self.nextFrameTime = time + 0.6
	else
		self.nextFrameTime = time + 0.1
	end if
end function

colors = ["#FFAAAA", "#AAFFAA", "#AAAAFF", "#FFFFAA", "#FFAAFF"]
addBlock = function(x, y, z=0)
	b = new Block
	b.image = frames[abs(round(x))][2]
	display(4).sprites.push b
	b.place x, y, z
	b.tint = colors.any
	return b
end function

// draw some blocks in the bin
for x in range(-2, 2)
	addBlock x, 0
	addBlock x, 1
end for
for y in range (2,4)
	addBlock 1, y
end for

// and stack up some blocks on the catcher
// (which is at z=1, goes up to just below the track)
for y in range(trackRow-6, trackRow-1)
	addBlock -1, y, 1
end for

// main loop
b = addBlock(1, trackRow, 20)
b.nextFrameTime = 0.25
while true
	b.update
	yield
end while