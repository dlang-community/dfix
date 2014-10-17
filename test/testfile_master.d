pure nothrow void doStuff(int x[]) {
	try
		whatever();
	catch
		somethingElse();
}

int someMapping[string];

void* pointers[];

enum a = "a";
enum someString = "123"
"456";

alias x y;

template Tst(string s) { enum Tst = s; }
alias Tst!"Test" Mod;
alias Tst!"Test2" Mod2;

alias immutable(int) IInt;
