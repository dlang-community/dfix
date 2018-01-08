pure nothrow void doStuff(int[] x) {
	try
		whatever();
	catch (Throwable)
		somethingElse();
	asm pure
	{
		mov sp[EBP], ESP;
		inc _iSemlockCtrs[EDX * 2];
	}
}

int[string] someMapping;

void*[] pointers;
int[][] multiDim;
int[b][a] multiDim;

enum a = "a";
enum someString = "123"
~ "456";

alias y = x;

template Tst(string s) { enum Tst = s; }
alias Mod = Tst!"Test";
alias Mod2 = Tst!"Test2";

alias IInt = immutable(int);

alias WNDPROC = LRESULT function (HWND, UINT, WPARAM, LPARAM);
alias LPOFNHOOKPROC = UINT function (HWND, UINT, WPARAM, LPARAM);
alias LanguageSpecificHandler = EXCEPTION_DISPOSITION function (
	EXCEPTION_RECORD *exceptionRecord,
	DEstablisherFrame *frame,
	CONTEXT *context,
	void *dispatcherContext);
private extern (D) alias fp_t = void function (Object);

alias Opcode = static immutable(OpInfo);
alias EntryFn = extern (C) void function();

alias Vector = __vector(T);


alias __externC = extern(C) RT function(P) nothrow @nogc;

private alias __dl_iterate_hdr_callback = extern(C) int function(dl_phdr_info*, size_t, void*);
alias externCVoidFunc = extern(C) void function();
alias ScanAllThreadsFn = void delegate(void*, void*) nothrow; /// The scanning function.
alias ScanAllThreadsTypeFn = void delegate(ScanType, void*, void*) nothrow; /// ditto
alias gcGetFn = void* function();

alias PCONTEXT = CONTEXT*, LPCONTEXT = CONTEXT*;
alias PEXCEPTION_RECORD = EXCEPTION_RECORD*, LPEXCEPTION_RECORD = EXCEPTION_RECORD*;
alias PEXCEPTION_POINTERS = EXCEPTION_POINTERS*, LPEXCEPTION_POINTERS = EXCEPTION_POINTERS*;

void foo() { ("abc%s" ~ "def%s").format("123", "456"); }
void bar() { "ghi".writeln(); }

enum SomeEnum { a, b }
struct SomeStruct { int a; }

struct MisplacedAttribute
{
	int aFunction() const nothrow { return 1; }
	int bFunction(T)() const { return 1; }
	int cFunction() const { return 1; }
	int dFunction() const
	{
		return 1;
	}
}

deprecated("string" "concat") int x;

enum bool isSome(T) = is(T == int);

immutable(char) toString() const;
string[] doStuff() const;
string* doStuff() const;

alias c = a .b;

size_t replicateBits(size_t , )() {}

void bodyToDo()
in {}
do {}
