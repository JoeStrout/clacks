// Animated starfield

Star = new Sprite
Star.init = function()
	self.scale = 0.1 + rnd*0.1
	self.x = 10 * (rnd-0.5); self.y = 10 * (rnd-0.5)	
	self.endTint = rgb(100 + 155*rnd, 100 + 155*rnd, 100 + 155*rnd)
	self.t = 0
	self.tint = color.clear
end function
Star.update = function(speed=1)
	f = 1.01 ^ speed
	self.x = self.x * f
	self.y = self.y * f
	f = 0.002 * speed
	self.scale = self.scale + f
	self.t = self.t + f
	self.tint = color.lerp(color.clear, self.endTint, self.t)
	if self.x < -500 or self.x > 500 or 
	       self.y-disp.scrollY < -20 or self.y-disp.scrollY > 660 then
		self.init
	end if
end function
Star1 = new Star
Star1.image = file.loadImage("pics/star1.png")

Star2 = new Star
Star2.image = file.loadImage("pics/star2.png")

update = function(speed=1)
	if disp == null then return
	for s in disp.sprites; s.update speed; end for
end function

disp = null

setup = function()
	display(6).mode = displayMode.sprite
	outer.disp = display(6)
	disp.clear
	disp.scrollX = -480; disp.scrollY = -500
	gfx.clear color.clear
	
	n = 100
	sprites = []
	for i in range(0, n-1)
		if rnd < 0.5 then s = new Star1 else s = new Star2
		s.init
		s.update 1000 * rnd
		sprites.push s
	end for
	disp.sprites = sprites
end function	


if locals == globals then
	setup
	while not key.pressed("escape")
		update
		yield
	end while
	key.clear
end if
