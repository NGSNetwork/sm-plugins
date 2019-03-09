#include <system2>

public void OnPluginStart()
{
  RegServerCmd("sm_shell", CommandShellCallback, "A direct shell to run commands on.");
}

public Action CommandShellCallback(int args)
{
  char arg[256];
  GetCmdArg(1, arg, sizeof(arg));
  StripQuotes(arg);
  System2_ExecuteThreaded(ShellCommandCallback, arg);
}

public void ShellCommandCallback(bool success, const char[] command, System2ExecuteOutput output, any data)
{
	if (!success || output.ExitStatus != 0)
	{
		LogError("Couldn't execute shell command %s successfully, exit status is %d!", command, output.ExitStatus);
  }
  else
  {
    int len = output.Length;
    char[] outputStr = new char[len];
    output.GetOutput(outputStr, len);
    PrintToServer("Output is:\n%s", outputStr);
  }
}
