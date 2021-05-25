-- Most of these tests are taken from lpeg and lpeglabel projects.

local lpegrex = require 'lpegrex'
local lpeg = require 'lpeglabel'
local lester = require 'tests.lester'

local describe, it, expect = lester.describe, lester.it, lester.expect
local eq, truthy, falsy = expect.equal, expect.truthy, expect.falsy
local compile, match, find, gsub = lpegrex.compile, lpegrex.match, lpegrex.find, lpegrex.gsub

local function genallchar()
  local allchar = {}
  for i=0,255 do
    allchar[i + 1] = i
  end
  local unpack = table.unpack or unpack
  allchar = string.char(unpack(allchar))
  assert(#allchar == 256)
  return allchar
end

local allchar = genallchar()

local function cs2str(c)
  return lpeg.match(lpeg.Cs((c + lpeg.P(1)/"")^0), allchar)
end

describe('lpeg patterns', function()

it("basic", function()
  eq(match("a", "."), 2)
  eq(match("a", "''"), 1)
  eq(match("", " ! . "), 1)
  falsy(match("a", " ! . "))
  eq(match("abcde", "  ( . . ) * "), 5)
  eq(match("abbcde", " [a-c] +"), 5)
  eq(match("0abbc1de", "'0' [a-c]+ '1'"), 7)
  eq(match("0zz1dda", "'0' [^a-c]+ 'a'"), 8)
  eq(match("abbc--", " [a-c] + +"), 5)
  eq(match("abbc--", " [ac-] +"), 2)
  eq(match("abbc--", " [-acb] + "), 7)
  falsy(match("abbcde", " [b-z] + "))
  eq(match("abb\"de", '"abb"["]"de"'), 7)
  eq(match("abceeef", "'ac' ? 'ab' * 'c' { 'e' * } / 'abceeef' "), "eee")
  eq(match("abceeef", "'ac'? 'ab'* 'c' { 'f'+ } / 'abceeef' "), 8)
  eq(match("aaand", "[a]^2"), 3)
end)

it("predicates", function()
  eq({match("abceefe", "( ( & 'e' {} ) ? . ) * ")}, {4, 5, 7})
  eq({match("abceefe", "((&&'e' {})? .)*")}, {4, 5, 7})
  eq({match("abceefe", "( ( ! ! 'e' {} ) ? . ) *")}, {4, 5, 7})
  eq({match("abceefe", "(( & ! & ! 'e' {})? .)*")}, {4, 5, 7})
end)

it("ordered choice", function()
  eq(match("cccx" , "'ab'? ('ccc' / ('cde' / 'cd'*)? / 'ccc') 'x'+"), 5)
  eq(match("cdx" , "'ab'? ('ccc' / ('cde' / 'cd'*)? / 'ccc') 'x'+"), 4)
  eq(match("abcdcdx" , "'ab'? ('ccc' / ('cde' / 'cd'*)? / 'ccc') 'x'+"), 8)

  eq(match("abc", "a <- (. a)?"), 4)

  local p = "balanced <- '(' ([^()] / balanced)* ')'"
  truthy(match("(abc)", p))
  truthy(match("(a(b)((c) (d)))", p))
  falsy(match("(a(b ((c) (d)))", p))

  local c = compile[[  balanced <- "(" ([^()] / balanced)* ")" ]]
  eq(c, lpeg.P(c))
  truthy(c:match"((((a))(b)))")

  c = [[
    S <- "0" B / "1" A / ""   -- balanced strings
    A <- "0" S / "1" A A      -- one more 0
    B <- "1" S / "0" B B      -- one more 1
  ]]
  eq(match("00011011", c), 9)

  c = [[
    S <- ("0" B / "1" A)*
    A <- "0" / "1" A A
    B <- "1" / "0" B B
  ]]
  eq(match("00011011", c), 9)
  eq(match("000110110", c), 9)
  eq(match("011110110", c), 3)
  eq(match("000110010", c), 1)
end)

it("repetitions", function()
  local s = "aaaaaaaaaaaaaaaaaaaaaaaa"
  eq(match(s, "'a'^3"), 4)
  eq(match(s, "'a'^0"), 1)
  eq(match(s, "'a'^+3"), s:len() + 1)
  falsy(match(s, "'a'^+30"))
  eq(match(s, "'a'^-30"), s:len() + 1)
  eq(match(s, "'a'^-5"), 6)
  for i = 1, s:len() do
    truthy(match(s, string.format("'a'^+%d", i)) >= i + 1)
    truthy(match(s, string.format("'a'^-%d", i)) <= i + 1)
    truthy(match(s, string.format("'a'^%d", i)) == i + 1)
  end

  eq(match("01234567890123456789", "[0-9]^3+"), 19)
end)

it("substitutions", function()
  eq(match("01234567890123456789", "({....}{...}) -> '%2%1'"), "4560123")
  eq(match("0123456789", "{| {.}* |}"), {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"})
  eq(match("012345", "{| (..) -> '%0%0' |}")[1], "0101")

  eq(match("abcdef", "( {.} {.} {.} {.} {.} ) -> 3"), "c")
  eq(match("abcdef", "( {:x: . :} {.} {.} {.} {.} ) -> 3"), "d")
  eq(match("abcdef", "( {:x: . :} {.} {.} {.} {.} ) -> 0"), 6)

  falsy(match("abcdef", "{:x: ({.} {.} {.}) -> 2 :} =x"))
  truthy(match("abcbef", "{:x: ({.} {.} {.}) -> 2 :} =x"))
end)

  it("sets", function()
    local function eqcharset(c1, c2)
      eq(cs2str(c1), cs2str(c2))
    end

    eqcharset(compile"[]]", "]")
    eqcharset(compile"[][]", lpeg.S"[]")
    eqcharset(compile"[]-]", lpeg.S"-]")
    eqcharset(compile"[-]", lpeg.S"-")
    eqcharset(compile"[az-]", lpeg.S"a-z")
    eqcharset(compile"[-az]", lpeg.S"a-z")
    eqcharset(compile"[a-z]", lpeg.R"az")
    eqcharset(compile"[]['\"]", lpeg.S[[]['"]])

    local any = lpeg.P(1)
    eqcharset(compile"[^]]", any - "]")
    eqcharset(compile"[^][]", any - lpeg.S"[]")
    eqcharset(compile"[^]-]", any - lpeg.S"-]")
    eqcharset(compile"[^]-]", any - lpeg.S"-]")
    eqcharset(compile"[^-]", any - lpeg.S"-")
    eqcharset(compile"[^az-]", any - lpeg.S"a-z")
    eqcharset(compile"[^-az]", any - lpeg.S"a-z")
    eqcharset(compile"[^a-z]", any - lpeg.R"az")
    eqcharset(compile"[^]['\"]", any - lpeg.S[[]['"]])
  end)

  it("predefined names", function()
    eq(os.setlocale("C"), "C")

    local function eqlpeggsub(p1, p2)
      eq(cs2str(compile(p1)), allchar:gsub("[^" .. p2 .. "]", ""))
    end

    eqlpeggsub("%w", "%w")
    eqlpeggsub("%a", "%a")
    eqlpeggsub("%l", "%l")
    eqlpeggsub("%u", "%u")
    eqlpeggsub("%p", "%p")
    eqlpeggsub("%d", "%d")
    eqlpeggsub("%x", "%x")
    eqlpeggsub("%s", "%s")
    eqlpeggsub("%c", "%c")

    eqlpeggsub("%W", "%W")
    eqlpeggsub("%A", "%A")
    eqlpeggsub("%L", "%L")
    eqlpeggsub("%U", "%U")
    eqlpeggsub("%P", "%P")
    eqlpeggsub("%D", "%D")
    eqlpeggsub("%X", "%X")
    eqlpeggsub("%S", "%S")
    eqlpeggsub("%C", "%C")

    eqlpeggsub("[%w]", "%w")
    eqlpeggsub("[_%w]", "_%w")
    eqlpeggsub("[^%w]", "%W")
    eqlpeggsub("[%W%S]", "%W%S")

    lpegrex.updatelocale()
  end)

it("comments", function()
  local c = compile[[
    A  <- _B   -- \t \n %nl .<> <- -> --
    _B <- 'x'  --]]
  eq(c:match'xy', 2)
end)

it("pre-definitions", function()
  local defs = {digits = lpeg.R"09", letters = lpeg.R"az", _=lpeg.P"__"}
  local c = compile("%letters (%letters / %digits)*", defs)
  eq(c:match"x123", 5)
  c = compile("%_", defs)
  eq(c:match"__", 3)

  c = compile([[
    S <- A+
    A <- %letters+ B
    B <- %digits+
  ]], defs)
  eq(c:match("abcd1234"), 9)

  c = compile("{[0-9]+'.'?[0-9]*} -> sin", math)
  eq(c:match("2.34"), math.sin(2.34))
end)

it("back reference", function()
  local c = compile([[
    longstring <- '[' {:init: '='* :} '[' close
    close <- ']' =init ']' / . close
  ]])

  eq(c:match'[==[]]===]]]]==]===[]', 17)
  eq(c:match'[[]=]====]=]]]==]===[]', 14)
  falsy(c:match'[[]=]====]=]=]==]===[]')

  c = compile" '[' {:init: '='* :} '[' (!(']' =init ']') .)* ']' =init ']' !. "

  truthy(c:match'[==[]]===]]]]==]')
  truthy(c:match'[[]=]====]=][]==]===[]]')
  falsy(c:match'[[]=]====]=]=]==]===[]')

  c = compile([[
    doc <- block !.
    block <- (start {| (block / { [^<]+ })* |} end?) => addtag
    start <- '<' {:tag: [a-z]+ :} '>'
    end <- '</' { =tag } '>'
  ]], {addtag = function(_, i, t, tag) t.tag = tag return i, t end})

  local t = c:match[[<x>hi<b>hello</b>but<b>totheend</x>]]
  eq(t, {tag='x', 'hi', {tag = 'b', 'hello'}, 'but', {'totheend'}})
end)

it("find", function()
  eq(find("hi alalo", "{:x:..:} =x"), 4)
  eq(find("hi alalo", "{:x:..:} =x", 4), 4)
  falsy(find("hi alalo", "{:x:..:} =x", 5))
  eq(find("hi alalo", "{'al'}", 5), 6)
  eq(find("hi aloalolo", "{:x:..:} =x"), 8)
  eq(find("alo alohi x x", "{:word:%w+:}%W*(=word)!%w"), 11)
  eq(find("", "!."), 1)
  eq(find("alo", "!."), 4)

  -- find discards any captures
  eq({2,3,nil}, {find("alo", "{.}{'o'}")})

  local function fmatch(s, p)
    local i,e = find(s,p)
    if i then return s:sub(i, e) end
  end
  eq(fmatch("alo alo", '[a-z]+'), "alo")
  eq(fmatch("alo alo", '{:x: [a-z]+ :} =x'), nil)
  eq(fmatch("alo alo", "{:x: [a-z]+ :} ' ' =x"), "alo alo")
end)

it("gsub", function()
  eq(gsub("alo alo", "[abc]", "x"), "xlo xlo")
  eq(gsub("alo alo", "%w+", "."), ". .")
  eq(gsub("hi, how are you", "[aeiou]", string.upper), "hI, hOw ArE yOU")
  local s = 'hi [[a comment[=]=] ending here]] and [=[another]]=]]'
  local c = compile" '[' {:i: '='* :} '[' (!(']' =i ']') .)* ']' { =i } ']' "
  eq(gsub(s, c, "%2"), 'hi  and =]')
  eq(gsub(s, c, "%0"), s)
  eq(gsub('[=[hi]=]', c, "%2"), '=')
end)

it("folding captures", function()
  local c = compile([[
    S <- (number (%s+ number)*) ~> add
    number <- %d+ -> tonumber
  ]], {tonumber = tonumber, add = function(a,b) return a + b end})
  eq(c:match("3 401 50"), 3 + 401 + 50)
end)

it("look-ahead captures", function()
  eq({match("alo", "&(&{.}) !{'b'} {&(...)} &{..} {...} {!.}")},
    {"", "alo", ""})
  eq(match("aloalo", "{~ (((&'al' {.}) -> 'A%1' / (&%l {.}) -> '%1%1') / .)* ~}"),
    "AallooAalloo")
  eq(match("alo alo", [[   {~ (&(. ([a-z]* -> '*')) ([a-z]+ -> '+') ' '*)* ~}  ]]),
    "+ +")
  eq(match("hello aloaLo aloalo xuxu", [[S <- &({:two: .. :} . =two) {[a-z]+} / . S]]),
    "aloalo")

  local c = compile[[
    block <- {| {:ident:space*:} line
             ((=ident !space line) / &(=ident space) block)* |}
    line <- {[^%nl]*} %nl
    space <- '_'     -- should be ' ', but '_' is simpler for editors
  ]]
  local t = c:match[[
1
__1.1
__1.2
____1.2.1
____
2
__2.1
  ]]
  eq(t, {"1", {"1.1", "1.2", {"1.2.1", "", ident = "____"}, ident = "__"},
              "2", {"2.1", ident = "__"}, ident = ""})
end)

it("nested grammars", function()
  local c = compile[[
     s <- a b !.
     b <- ( x <- ('b' x)? )
     a <- ( x <- 'a' x? )
  ]]
  truthy(c:match'aaabbb')
  truthy(c:match'aaa')
  falsy(c:match'bbb')
  falsy(c:match'aaabbba')
end)

it("groups", function()
  eq({match("abc", "{:S <- {:.:} {S} / '':}")}, {"a", "bc", "b", "c", "c", ""})
  eq(match("1234", "{| {:a:.:} {:b:.:} {:c:.{.}:} |}"), {a="1", b="2", c="4"})
  eq(match("1234", "{|{:a:.:} {:b:{.}{.}:} {:c:{.}:}|}"), {a="1", b="2", c="4"})
  eq(match("12345", "{| {:.:} {:b:{.}{.}:} {:{.}{.}:} |}"), {"1", b="2", "4", "5"})
  eq(match("12345", "{| {:.:} {:{:b:{.}{.}:}:} {:{.}{.}:} |}"), {"1", "23", "4", "5"})
  eq(match("12345", "{| {:.:} {{:b:{.}{.}:}} {:{.}{.}:} |}"), {"1", "23", "4", "5"})
end)

it("nested substitutions", function()
  local c = compile[[
    text <- {~ item* ~}
    item <- macro / [^()] / '(' item* ')'
    arg <- ' '* {~ (!',' item)* ~}
    args <- '(' arg (',' arg)* ')'
    macro <- ('apply' args) -> '%1(%2)'
           / ('add' args) -> '%1 + %2'
           / ('mul' args) -> '%1 * %2'
  ]]
  eq(c:match"add(mul(a,b), apply(f,x))", "a * b + f(x)")

  c = compile[[ R <- (!.) -> '' / ({.} R) -> '%2%1']]
  eq(c:match"0123456789", "9876543210")
end)

it("grammar syntax errors", function()
  expect.fail(function() compile('aaaa') end, "rule 'aaaa'")
  expect.fail(function() compile('a') end, 'outside')
  expect.fail(function() compile('b <- a') end, 'undefined')
  expect.fail(function() compile('b <- %invalid') end, 'undefined')
  expect.fail(function() compile("x <- 'a'  x <- 'b'") end, 'already defined')
  expect.fail(function() compile("'a' -") end, 'incorrect pattern')
end)

it("error labels", function()
  local c = compile[['a' / %{l1}]]
  eq(c:match("a"), 2)
  eq({nil, 'l1', 1}, {c:match("b")})

  c = compile[['a'^l1]]
  eq({nil, 'l1', 1}, {c:match("b")})

  c = compile[[
    A <- 'a'^B
    B <- [a-f]^C
    C <- [a-z]
  ]]
  eq(c:match("a"), 2)
  eq(c:match("a"), 2)
  eq(c:match("f"), 2)
  eq(c:match("g"), 2)
  eq(c:match("z"), 2)
  eq({nil, 'fail', 1}, {c:match("A")})

  c = compile[[
    A <- %{C}
    B <- [a-z]
  ]]
  eq({nil, 'C', 1}, {c:match("a")})

  c = compile[[A <- %{B}
                  B <- [a-z]
  ]]
  eq(c:match("a"), 2)
  eq({nil, 'fail', 1}, {c:match("U")})

  c = compile[[
    A <- [a-f] %{B}
    B <- [a-c] %{C}
    C <- [a-z]
  ]]
  eq({nil, 'fail', 2}, {c:match("a")})
  eq({nil, 'fail', 3}, {c:match("aa")})
  eq(c:match("aaa"), 4)
  eq({nil, 'fail', 2}, {c:match("ad")})
  eq({nil, 'fail', 1}, {c:match("g")})

  --[[ grammar based on Figure 8 of paper submitted to SCP (using the recovery operator)
  S  -> S0 //{1} ID //{2} ID '=' Exp //{3} 'unsigned'* 'int' ID //{4} 'unsigned'* ID ID / %error
  S0 -> S1 / S2 / &'int' %3
  S1 -> &(ID '=') %2  /  &(ID !.) %1  /  &ID %4
  S2 -> &('unsigned'+ ID) %4  /  & ('unsigned'+ 'int') %3
  ]]

  c = compile([[
    S <- S0 / %{L5}
    S0 <- S1 / S2 / &Int %{L3}
    S1 <- &(ID %s* '=') %{L2} / &(ID !.) %{L1} / &ID %{L4}
    S2 <- &(U+ ID) %{L4} / &(U+ Int) %{L3}
    ID <- %s* 'a'
    U <- %s* 'unsigned'
    Int <- %s* 'int'
    Exp <- %s* 'E'
    L1 <- ID
    L2 <- ID %s* '=' Exp
    L3 <- U* Int ID
    L4 <- U ID ID
  ]])
  local s = "a"
  eq(c:match(s), #s + 1)
  s = "a = E"
  eq(c:match(s), #s + 1)
  s = "int a"
  eq(c:match(s), #s + 1)
  s = "unsigned int a"
  eq(c:match(s), #s + 1)
  s = "unsigned a a"
  eq(c:match(s), #s + 1)
  s = "b"
  eq({nil, 'L5', 1}, {c:match(s)})
  s = "unsigned"
  eq({nil, 'L5', 1}, {c:match(s)})
  s = "unsigned a"
  eq({nil, 'L5', 1}, {c:match(s)})
  s = "unsigned int"
  eq({nil, 'L5', 1}, {c:match(s)})
end)

it("error labels with captures", function()
  local c = compile[[
    S <- ( %s* &. {A} )*
    A <- [0-9]+ / %{5}
  ]]
  eq({"523", "624", "346", "888"} , {c:match("523 624  346\n888")})
  eq({nil, 5, 4}, {c:match("44 a 123")})

  c = compile[[
    S <- ( %s* &. {A} )*
    A <- [0-9]+ / %{Rec}
    Rec <- ((![0-9] .)*) -> "58"
  ]]
  eq({"523", "624", "346", "888"} , {c:match("523 624  346\n888")})
  eq({"44", "a ", "58", "123"}, {c:match("44 a 123")})

  c = compile[[
    S <- ( %s* &. A )*
    A <- {[0-9]+} / %{5}
  ]]
  eq({"523", "624", "346", "888"} , {c:match("523 624  346\n888")})
  eq({nil, 5, 4}, {c:match("44 a 123")})

  c = compile[[
    S <- ( %s* &. A )*
    A <- {[0-9]+} / %{Rec}
    Rec <- ((![0-9] .)*) -> "58"
  ]]
  eq({"523", "624", "346", "888"} , {c:match("523 624  346\n888")})
  eq({"44", "58", "123"}, {c:match("44 a 123")})
end)

end)

describe("lpegrex extensions", function()

it("control characters patterns", function()
  eq(match('\a', "%ca"), 2)
  eq(match('\b', "%cb"), 2)
  eq(match('\f', "%cf"), 2)
  eq(match('\n', "%cn"), 2)
  eq(match('\r', "%cr"), 2)
  eq(match('\t', "%ct"), 2)
  eq(match('\v', "%cv"), 2)
  eq(match('\a\b\f\n\r\t\v', "%ca"), 2)
end)

it("arbitrary captures", function()
  local c = compile([[$nil $true $false ${} $myvar]], { myvar = 'hello'})
  eq({nil, true, false, {}, 'hello'}, {c:match('')})

  c = compile([[$'text' $"something" $0 $-1]])
  eq({'text', "something", 0, -1}, {c:match('')})
end)

it("token and keywords literals", function()
  eq(match('a', [[A <- `a` SKIP <- %s*]]), 2)
  eq(match('{', [[A <- `{` SKIP <- %s*]]), 2)
  eq(match('`', [[A <- ``` SKIP <- %s*]]), 2)
  eq(match('a : c', [[G <- `a` `:` `c` SKIP <- %s*]]), 6)
  eq(match('local function()',
           [[A <- `local` `function` `(` `)` SKIP <- %s*]]), 17)
end)

it("auxiliary functions", function()
  eq(match('dummy', '%a+ -> tonil'), nil)
  eq(match('dummy', '%a+ -> tofalse'), false)
  eq(match('dummy', '%a+ -> totrue'), true)
  eq(match('1234', '%d+ -> tonumber'), 1234)
  eq(match('ff', '({%x+} $16) -> tonumber'), 0xff)
  eq(match('65', '%d+ -> tochar'), string.char(65))
  eq(match('41', '({%x+} $16) -> tochar'), string.char(0x41))

  local c = compile([[( ({|{%a+}|}%s*)* ) ~> rfold]])
  eq(c:match('a'), {'a'})
  eq(c:match('a b'), {'b', {'a'}})
  eq(c:match('a b c'), {'c', {'b', {'a'}}})
end)

it("expected matches", function()
  local c = compile[[@'test' %s* @"aaaa"]]
  eq(c:match'test aaaa', 10)
  eq({nil, 'Expected_test', 1}, {c:match'tesi aaaa'})
  eq({nil, 'Expected_aaaa', 6}, {c:match'test aaab'})

  c = compile[[
    rules <- @`test` @`aaaa`
    SKIP <- %s*
  ]]
  eq(c:match'test aaaa', 10)
  eq({nil, 'Expected_test', 1}, {c:match'tesi aaaa'})
  eq({nil, 'Expected_aaaa', 6}, {c:match'test aaab'})

  c = compile[[
    rules <- @test %s* @aaaa
    test <- 'test'
    aaaa <- 'aaaa'
  ]]
  eq({nil, 'ExpectedRule_test', 1}, {c:match'tesi aaaa'})
  eq({nil, 'ExpectedRule_aaaa', 6}, {c:match'test aaab'})

end)

it("table capture", function()
  local c = compile[[
    chunk  <-- Numbers
    Numbers <-| NUMBER NUMBER
    NUMBER <-- {%d+} SKIP
    SKIP   <-- %s*
  ]]
  eq({"1234", "5678"}, c:match('1234 5678'))
end)

it("node capture", function()
  local c = compile[[
    chunk  <-- Number
    Number <== NUMBER
    NUMBER <-- {%d+} SKIP
    SKIP   <-- %s*
  ]]
  eq({tag="Number", pos=1, endpos=5, "1234"}, c:match('1234'))
end)

it("grammar syntax errors", function()
  -- expect.fail(function() compile([[~]]) end, "asd")
end)

end)

lester.report()
