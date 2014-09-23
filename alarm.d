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
alarm 60m

Info:
Wait for e.g. 60 minutes before notifying the user.
s = seconds, m = minutes, h = hours.
Logs the start time to %s.

User can choose:
Abort - quit.
Retry - restart timer.
Ignore - postpone dialog (waits for duration / 10).
".strip;

void run(string[] args)
{
	// TODO: change to user config dir?
	string logfile = buildPath(dirName(args.front), "alarm.txt");
	if (args.length != 2 || args[1].empty)
	{
	missing:
		auto msg = usage.format(logfile);
		messageBox(msg.toUTF16z, "Missing or wrong arguments specified!");
		writeln(msg);
		return;
	}
	auto durStr = args[1];
	size_t sMul = 1;
	switch (durStr.back)
	{
		case 'h': sMul *= 60; goto case;
		case 'm': sMul *= 60; goto case;
		case 's': durStr.popBack(); break;
		default:
			goto missing;
	}
	size_t durSecs;
	try durSecs = to!size_t(durStr);
	catch (ConvException e)
	{
		messageBox(format("Can't convert '%s' to integer: %s!",
			durStr, e.msg).toUTF16z, "Error!");
		return;
	}
	durSecs *= sMul;
	auto getDur(size_t secs){return dur!"seconds"(secs);}
	void sleep(size_t secs){
		import core.thread;
		Thread.sleep(getDur(secs));
	}
	auto currTime(){return cast(DateTime)Clock.currTime();}

	while(1)
	{
		auto start = currTime();
		auto logmsg = text("Started:\t", start,
			"\nTimer duration: ", getDur(durSecs),
			"\nEnd time:\t", start + durSecs.seconds);
		File(logfile, "w").writeln(logmsg);
		logmsg.writeln;

		sleep(durSecs);
		auto ignoreMul = 1.0;
		while(1)
		{
			auto msgtime = currTime();
			auto elapsed = msgtime - start;
			auto msg = format("Elapsed: %s\n\n%s", elapsed, logmsg);
			auto id = messageBox(msg.toUTF16z, "Time's up",
				MB_ABORTRETRYIGNORE, MB_ICONWARNING, MB_DEFBUTTON3);

			if (id == IDABORT)
			{
				if (messageBox("Are you sure?", "Quit",
					MB_YESNO, MB_ICONQUESTION) == IDYES)
					return;
			}
 			/* confirm actions in case of accidentally
			 * typing [ri] just as the dialog is shown */
			else if (id == IDRETRY)
			{
				if (currTime() - msgtime < 5.seconds &&
					messageBox("Are you sure?", null,
						MB_YESNO, MB_ICONQUESTION) != IDYES)
					continue;
				break;
			}
			else if (id == IDIGNORE)
			{
				if (currTime() - msgtime < 2.seconds &&
					messageBox("Are you sure?", null,
						MB_YESNO, MB_ICONQUESTION) != IDYES)
					continue;
				// wait time depends on timer duration
				auto t = durSecs / 10.0;
				// grow ignore time
				t *= ignoreMul;
				ignoreMul *= 1.2;
				// limit to 30m
				const max = 30 * 60;
				t = t > max ? max : t;
				debug writefln("Postponed %ss", t);
				sleep(cast(uint)t);
			}
		}
	}
}

