import std.stdio;
import libconfig;

void main ()
{
	auto config = new Config("test.config");

	assert(config["version"].value == "1.0");
	assert(config["application"].isGroup);
	assert(config["application"]["list"].length == 3);
	assert(config["application"]["books"][0]["price"].value == 29.95);
}
