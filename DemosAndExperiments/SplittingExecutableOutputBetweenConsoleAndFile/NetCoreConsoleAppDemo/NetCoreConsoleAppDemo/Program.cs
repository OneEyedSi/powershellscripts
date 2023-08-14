using System;

namespace NetCoreConsoleAppDemo
{
    class Program
    {
        static int Main(string[] args)
        {
            Console.WriteLine("Hello World!");
            Console.WriteLine();

            if (args.Length == 0)
            {
                Console.WriteLine("No command line arguments passed in.");
            }
            else
            {
                Console.WriteLine("Command line arguments supplied:");

                for (int i = 0; i < args.Length; i++)
                {
                    Console.WriteLine($"    {i}: {args[i]}");
                }
            }
            Console.WriteLine();

            for (int i = 0; i < 10; i++)
            {
                Console.WriteLine($"Before error {i}");
            }
            Console.WriteLine();

            Console.Error.WriteLine("ERROR!!");
            Console.WriteLine();

            for (int i = 0; i < 10; i++)
            {
                Console.WriteLine($"After {i}");
            }

            Console.WriteLine();

            // According to this Stackoverflow thread, 
            //  "How do I specify the exit code of a console application in .NET?", 
            //  https://stackoverflow.com/a/155619/216440 ,
            //  the easiest way to explictly set the exit code of a console application is to 
            //  change the signature of the Main method from 
            //      static void Main(string[] args)
            //  to
            //      static int Main(string[] args)
            //  and then, from within the Main method return <integer>, where <integer> is the 
            //  exit code.
            int exitCode = 0;
            if (args?.Length > 0)
            {
                int.TryParse(args[0], out exitCode);
            }

            Console.WriteLine($"Expected exit code: {exitCode}");

            return exitCode;
        }
    }
}
