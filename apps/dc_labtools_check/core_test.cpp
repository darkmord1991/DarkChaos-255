// Checks for the DC LabTools core logic (src/server/scripts/DC/LabTools/*_core.cpp).
// Built and run by run.py in this directory; not part of the worldserver build.
#include "dc_lab_probe_core.h"
#include "dc_bug_report_core.h"
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>

static int pass = 0, fail = 0;
#define CHECK(c) do { if (c) ++pass; else { ++fail; std::printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); } } while (0)

using namespace DCLabProbe;

int main()
{
    // ids, commands, keys, strings
    CHECK(IsRequestId("0123456789"));
    CHECK(IsRequestId("abcdef0123"));
    CHECK(!IsRequestId("ABCDEF0123"));
    CHECK(!IsRequestId("012345678"));
    CHECK(!IsRequestId("0123456789a"));
    CHECK(IsReadOnlyCommand("frame") && IsReadOnlyCommand("cvars") && IsReadOnlyCommand("errors"));
    CHECK(!IsReadOnlyCommand("eval") && !IsReadOnlyCommand("run") && !IsReadOnlyCommand(""));
    CHECK(IsAllowedRequestKey("names") && !IsAllowedRequestKey("code"));
    CHECK(IsSafeRequestString("item:6948:0:0") && IsSafeRequestString("PlayerFrame") && IsSafeRequestString("raid12"));
    CHECK(!IsSafeRequestString("a b") && !IsSafeRequestString("x\"y") && !IsSafeRequestString("") && !IsSafeRequestString(std::string(97, 'a')));

    auto accounts = ParseAccountList(" lab1, Lab2;lab3\tLAB4 ,, ");
    CHECK(accounts.size() == 4);
    CHECK(IsListedAccount(accounts, "LAB1") && IsListedAccount(accounts, "lab4") && !IsListedAccount(accounts, "lab5"));
    CHECK(!IsListedAccount(ParseAccountList(""), "lab1"));
    CHECK(!IsListedAccount(accounts, ""));

    // result book
    ResultBook book;
    book.Configure(300000, 16384);
    book.Arm("000000000a", 1, "Alice", "frame", 1000);
    CHECK(book.Status("000000000a", 1000).state == ResultState::Pending);
    CHECK(book.Status("000000000b", 1000).state == ResultState::Unknown);
    CHECK(book.Accept(2, "000000000a", 1, 2, "ab", 1100) == AcceptResult::WrongPlayer);
    CHECK(book.Accept(1, "000000000b", 1, 2, "ab", 1100) == AcceptResult::UnknownRequest);
    CHECK(book.Accept(1, "000000000a", 0, 2, "ab", 1100) == AcceptResult::BadChunk);
    CHECK(book.Accept(1, "000000000a", 3, 2, "ab", 1100) == AcceptResult::BadChunk);
    CHECK(book.Accept(1, "000000000a", 1, 129, "ab", 1100) == AcceptResult::BadChunk);
    CHECK(book.Accept(1, "000000000a", 2, 2, "cd", 1100) == AcceptResult::Accepted);
    CHECK(book.Accept(1, "000000000a", 2, 2, "cd", 1100) == AcceptResult::Duplicate);
    CHECK(book.Accept(1, "000000000a", 1, 3, "ab", 1100) == AcceptResult::BadChunk);
    auto st = book.Status("000000000a", 1200);
    CHECK(st.state == ResultState::Pending && st.received == 1 && st.total == 2);
    CHECK(book.Accept(1, "000000000a", 1, 2, "ab", 1200) == AcceptResult::Completed);
    st = book.Status("000000000a", 1300);
    CHECK(st.state == ResultState::Complete && st.body == "abcd" && st.player == "Alice" && st.command == "frame");
    // readable again, expires after ttl
    CHECK(book.Status("000000000a", 1400).body == "abcd");
    CHECK(book.Status("000000000a", 1000 + 300001).state == ResultState::Unknown);

    // abandon on logout, complete stays
    book.Arm("00000000c1", 7, "Bob", "state", 5000);
    book.Arm("00000000c2", 7, "Bob", "state", 5000);
    CHECK(book.Accept(7, "00000000c2", 1, 1, "{}", 5001) == AcceptResult::Completed);
    book.AbandonPlayer(7);
    CHECK(book.Status("00000000c1", 5002).state == ResultState::Abandoned);
    CHECK(book.Status("00000000c2", 5002).state == ResultState::Complete);
    CHECK(book.Accept(7, "00000000c1", 1, 1, "x", 5003) == AcceptResult::UnknownRequest);

    // size cap
    ResultBook small;
    small.Configure(300000, 200);
    small.Arm("00000000d1", 9, "C", "addons", 0);
    CHECK(small.Accept(9, "00000000d1", 1, 3, std::string(150, 'x'), 1) == AcceptResult::Accepted);
    CHECK(small.Accept(9, "00000000d1", 2, 3, std::string(150, 'x'), 1) == AcceptResult::TooLarge);
    CHECK(small.Accept(9, "00000000d1", 3, 3, std::string(193, 'x'), 1) == AcceptResult::BadChunk);

    // per-player pending cap and global cap
    ResultBook capped;
    for (int i = 0; i < 10; ++i)
    {
        char id[11];
        std::snprintf(id, sizeof(id), "%010x", i);
        capped.Arm(id, 42, "P", "ping", 10);
    }
    CHECK(capped.Size() == MaxPendingPerPlayer);
    CHECK(capped.Status("0000000000", 11).state == ResultState::Unknown);
    CHECK(capped.Status("0000000009", 11).state == ResultState::Pending);
    ResultBook global;
    for (int i = 0; i < 100; ++i)
    {
        char id[11];
        std::snprintf(id, sizeof(id), "%010x", i);
        global.Arm(id, 1000 + i, "P", "ping", 10);
    }
    CHECK(global.Size() == MaxEntries);
    auto list = global.List(11);
    CHECK(list.size() == MaxEntries && list.front().first == "0000000063");

    // ---- bug report core ----
    using namespace DCBugReport;
    CHECK(CleanText("  hello\r\nworld\x01\x7f  ", 100, true) == "hello\nworld");
    CHECK(CleanText("a\nb\tc", 100, false) == "a b c");
    CHECK(CleanText("abc\r", 100, true) == "abc");
    // utf-8 boundary: "\xC3\xA4" is a-umlaut
    CHECK(CleanText("ab\xC3\xA4", 3, false) == "ab");
    CHECK(CleanText("ab\xC3\xA4", 4, false) == "ab\xC3\xA4");
    CHECK(CleanText("\xE2\x82\xAC\xE2\x82\xAC", 4, false) == "\xE2\x82\xAC");
    CHECK(IsValidCategory("quest") && !IsValidCategory("crash") && !IsValidCategory(""));

    RateLimiter limiter;
    CHECK(limiter.Check(5, 1000, 120, 3) == 0);
    limiter.Record(5, 1000);
    CHECK(limiter.Check(5, 1060, 120, 3) == 60);
    CHECK(limiter.Check(6, 1060, 120, 3) == 0);
    CHECK(limiter.Check(5, 1120, 120, 3) == 0);
    limiter.Record(5, 1120);
    limiter.Record(5, 1300);
    CHECK(limiter.Check(5, 1500, 120, 3) == 86400 - 500);
    CHECK(limiter.Check(5, 1000 + 86400, 120, 3) == 0);
    limiter.Record(5, 1000 + 86400);
    CHECK(limiter.Check(5, 1000 + 86400 + 121, 120, 3) == 0);
    CHECK(limiter.Check(5, 1060, 0, 0) == 0);

    CHECK(MakeReportId(0x6740a1b2, 0x1f, 0x12345) == "6740a1b2-1f-2345");
    CHECK(MakeReportId(1, 0, 7) == "1-0-0007");

    std::string path = (std::filesystem::temp_directory_path() / "dc_bug_spool_test.jsonl").string();
    std::filesystem::remove(path);
    std::string error;
    CHECK(AppendSpoolLine(path, "{\"a\":1}", 0, error));
    CHECK(AppendSpoolLine(path, "{\"b\":2}", 0, error));
    CHECK(!AppendSpoolLine(path, "x\ny", 0, error));
    CHECK(!AppendSpoolLine(path, "{\"c\":3}", 20, error) && error == "spool full");
    CHECK(!AppendSpoolLine("", "{}", 0, error));
    std::ifstream in(path, std::ios::binary);
    std::stringstream ss; ss << in.rdbuf();
    CHECK(ss.str() == "{\"a\":1}\n{\"b\":2}\n");
    in.close();
    std::filesystem::remove(path);

    std::printf("RESULT %d passed, %d failed\n", pass, fail);
    return fail ? 1 : 0;
}
