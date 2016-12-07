require("heartbeat")

for i=1,60,1 do
	upload()
	os.execute("sleep ".. 1)
end