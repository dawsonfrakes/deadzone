// 2>/dev/null; g++ $0 && ./a.out; exit
// Dawson, 10/18/22:
//  I haven't used C++ in roughly 4 years.
//  Andreas Kling made me think I should try it out again.
//  I'm going to attempt to implement the interpreter described at https://ruslanspivak.com/lsbasi-part1.
//  In theory this is step 1 to learning what I do and don't want in my system.

#include <iostream>
#include <vector>
#include <optional>
#include <string>

enum TokenType {
    id,
    plus,
    minus,
    integer
};

const char *TokenTypeString[] = {
    "ID",
    "Plus",
    "Minus",
    "Integer"
};

struct Token {
    TokenType type;
    std::optional<std::string> data = std::nullopt;
};

std::vector<Token> tokenize(std::string input)
{
    const size_t length = input.length();
    std::vector<Token> result;
    size_t pos = 0;
    while (pos < length) {
        // skip whitespace
        if (std::isspace(input[pos])) {
            ++pos;
            continue;
        }
        // integers
        if (std::isdigit(input[pos])) {
            size_t read = 0;
            result.push_back({integer, std::to_string(std::stoi(input.substr(pos), &read))});
            pos += read;
            continue;
        }
        // identifers / keywords
        if (std::isalpha(input[pos]) or input[pos] == '_') {
            char c;
            size_t i = 0;
            while (pos+i < length and (c = input.at(pos+i++)))
                if (!(std::isalnum(c) or c == '_')) break;
            result.push_back({id, input.substr(pos, i - 1)});
            pos += i;
            continue;
        }
        // operators
        switch (input[pos]) {
            case '+': {
                result.push_back({plus});
                ++pos;
            } continue;
            case '-': {
                result.push_back({minus});
                ++pos;
            } continue;
        }
        throw std::runtime_error(std::string("Symbol '") + input[pos] + "' not eligible for tokenization");
    }
    return result;
}

// typedef'd so I can decide which type of value is returned in the future
typedef int IntResult;

// expect tokens to be in a specific order for things to work correctly
struct Parser {
    // TODO: switch to using a std::vector<Token>::iterator instead of an index and a reference
    const std::vector<Token>& tokens;
    size_t current_token = 0;

    void eat(TokenType expect) {
        if (current_token >= tokens.size())
            throw std::runtime_error(std::string(TokenTypeString[expect]) + " expected and not found. I ran out of input!");
        if (tokens[current_token].type != expect)
            throw std::runtime_error(std::string(TokenTypeString[tokens[current_token].type]) + " != " + TokenTypeString[expect]);
        ++current_token;
    }

    IntResult term() {
        const size_t token = current_token;
        eat(integer);
        return std::stoi(tokens[token].data.value());
    }

    IntResult expr() {
        IntResult result = term();
        const size_t op = current_token;
        while (tokens[current_token].type == plus || tokens[current_token].type == minus) {
            switch (tokens[current_token].type) {
                case plus: eat(plus); result += term(); break;
                case minus: eat(minus); result -= term(); break;
            }
        }

        return result;
    }
};

int main()
{
    std::vector<Token> tokens = tokenize("22 + 5 - 10");
    Parser parser = {tokens};
    std::cout << "Parser result: " << parser.expr() << std::endl;
    std::cout << "Tokenizer result:" << std::endl;
    for (const Token& t : tokens) {
        std::cout << "\tType: " << TokenTypeString[t.type] << (t.data ? "; Data: \"" : "") << t.data.value_or("") << (t.data ? "\"" : "") << std::endl;
    }
}
