/*
 * alarm.d
 *
 * Copyright 2011-2013 Nick Treleaven <nick dot treleaven at btinternet com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 */

/* Note: Currently requires Windows for MessageBoxW dialog function */

import std.conv;
import std.stdio;
import std.string;
import std.array;
import std.algorithm;
import std.path;
import std.getopt;
import std.utf;
import std.datetime;
import std.c.windows.windows;

auto messageBox(const(wchar)* msg, const(wchar)* title,
	uint type = MB_OK, uint icon = MB_ICONINFORMATION, uint flags = 0)
{
	return MessageBoxW(null, msg, title, type | icon | flags | MB_TOPMOST);
}

void main(string[] args)
{
	try
		run(args);
	catch (Exception e)
	{
		messageBox(e.msg.toUTF16z, "Error!", MB_OK, MB_ICONERROR);
		throw e;
	}
}

enum string usage = "
Usage:
alarm 60 [-s]

Wait for e.g. 60 minutes before notifying the user.
-s uses seconds instead of minutes.
Logs the start time to %s.
".strip;

void run(string[] args)
{
	string logfile = buildPath(dirName(args.front), "alarm.txt");
	auto minuteMul = 60;
	getopt(args, "s", {minuteMul = 1;});
	if (args.length != 2)
	{
		auto msg = usage.format(logfile);
		messageBox(msg.toUTF16z, "Error!");
		writeln(msg);
		return;
	}
	size_t duration = to!size_t(args[1]);
	auto getDur(size_t n){return dur!"seconds"(n * minuteMul);}
	void sleep(size_t n){
		import core.thread;
		Thread.sleep(getDur(n));
	}
	auto currTime(){return cast(DateTime)Clock.currTime();}

	while(1)
	{
		auto start = currTime();
		auto startmsg = text("Started on ", start,
			"\nTimer duration: ", getDur(duration));
		File(logfile, "w").writeln(startmsg);

		sleep(duration);
		while(1)
		{
			auto msgtime = currTime();
			auto elapsed = msgtime - start;
			auto msg = format("Elapsed: %s\n\n%s", elapsed, startmsg);
			auto id = messageBox(msg.toUTF16z, "Time's up",
				MB_ABORTRETRYIGNORE, MB_ICONWARNING, MB_DEFBUTTON3);

			/* confirm important actions in case of accidentally
			 * typing [ar] just as the dialog is shown */
			if (id == IDRETRY)
			{
				if (currTime() - msgtime < 5.seconds &&
					messageBox("Are you sure?", "Restart",
						MB_YESNO, MB_ICONQUESTION) != IDYES)
					continue;
				break;
			}
			if (id == IDABORT && messageBox("Are you sure?", "Quit",
				MB_YESNO, MB_ICONQUESTION) == IDYES)
				return;
			if (id == IDIGNORE)
				sleep(5);
		}
	}
}
