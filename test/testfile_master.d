pure nothrow void doStuff(int x[]) {
	try
		whatever();
	catch
		somethingElse();
	asm pure
	{
		mov sp[EBP], ESP;
		inc _iSemlockCtrs[EDX * 2];
	}
}

int someMapping[string];

void* pointers[];
int multiDim[][];
int multiDim[a][b];

enum a = "a";
enum someString = "123"
"456";

alias x y;

template Tst(string s) { enum Tst = s; }
alias Tst!"Test" Mod;
alias Tst!"Test2" Mod2;

alias immutable(int) IInt;

alias LRESULT function (HWND, UINT, WPARAM, LPARAM) WNDPROC;
alias UINT function (HWND, UINT, WPARAM, LPARAM) LPOFNHOOKPROC;
alias EXCEPTION_DISPOSITION function (
	EXCEPTION_RECORD *exceptionRecord,
	DEstablisherFrame *frame,
	CONTEXT *context,
	void *dispatcherContext) LanguageSpecificHandler;
private extern (D) alias void function (Object) fp_t;

alias static immutable(OpInfo) Opcode;
alias extern (C) void function() EntryFn;

alias __vector(T) Vector;


alias extern(C) RT function(P) nothrow @nogc __externC;

private alias extern(C) int function(dl_phdr_info*, size_t, void*) __dl_iterate_hdr_callback;
alias extern(C) void function() externCVoidFunc;
alias void delegate(void*, void*) nothrow ScanAllThreadsFn; /// The scanning function.
alias void delegate(ScanType, void*, void*) nothrow ScanAllThreadsTypeFn; /// ditto
alias void* function() gcGetFn;

alias CONTEXT* PCONTEXT, LPCONTEXT;
alias EXCEPTION_RECORD* PEXCEPTION_RECORD, LPEXCEPTION_RECORD;
alias EXCEPTION_POINTERS* PEXCEPTION_POINTERS, LPEXCEPTION_POINTERS;

void foo() { "abc%s" "def%s".format("123", "456"); }
void bar() { "ghi".writeln(); }

enum SomeEnum { a, b };
struct SomeStruct { int a; };

struct MisplacedAttribute
{
	const int aFunction() nothrow { return 1; }
	const int bFunction(T)() { return 1; }
	const int cFunction(){ return 1; }
	const int dFunction()
	{
		return 1;
	}
}

deprecated("string" "concat") int x;

enum bool isSome(T) = is(T == int);

const immutable(char) toString();
const string[] doStuff();
const string* doStuff();

alias a .b c;

size_t replicateBits(size_t , )() {}

void bodyToDo()
in {}
body {}
