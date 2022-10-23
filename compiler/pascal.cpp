// 2>/dev/null; g++ $0 && ./a.out; exit
// Dawson, 10/18/22:
//  I haven't used C++ in roughly 4 years.
//  Andreas Kling made me think I should try it out again.
//  I'm going to attempt to implement the interpreter described at https://ruslanspivak.com/lsbasi-part1.
//  In theory this is step 1 to learning what I do and don't want in my system.
// Dawson, 10/19/22:
//  I've never used smart pointers before so my use is probably incorrect but it compiles and runs so w/e.
//  I should also note Lex Fridman's love of C++ may have also contributed to me coming back to it after so long.

#include <algorithm>
#include <iostream>
#include <memory>
#include <optional>
#include <string>
#include <unordered_map>
#include <vector>

enum TokenType {
    id,
    plus,
    minus,
    mul,
    div_integer,
    div_float,
    integer,
    lparen,
    rparen
};

const char *TokenTypeString[] = {
    "ID",
    "Plus",
    "Minus",
    "Mul",
    "DivInteger",
    "DivFloat",
    "Integer",
    "LParen",
    "RParen"
};

struct Token {
    TokenType type;
    std::optional<std::string> data = std::nullopt;
};

/// @brief Splits an input stream into parsable tokens
/// @param input: a block of text
/// @return A vector of tokens to be used by a parser
std::vector<Token> tokenize(std::string input)
{
    const std::unordered_map<std::string, Token> keywords = {
        {"div", {div_integer}}
    };
    const size_t length = input.length();
    std::vector<Token> result;
    for (size_t pos = 0; pos < length; ++pos) {
        // skip whitespace
        if (std::isspace(input[pos])) continue;
        // integers
        if (std::isdigit(input[pos])) {
            size_t read = 0;
            result.push_back({integer, std::to_string(std::stoi(input.substr(pos), &read))});
            pos += read - 1;
            continue;
        }
        // identifers / keywords
        if (std::isalpha(input[pos]) or input[pos] == '_') {
            size_t i;
            for (i = 1; pos + i < length; ++i) {
                const char &c = input.at(pos+i);
                if (not (std::isalnum(c) or c == '_')) break;
            }

            std::string word = input.substr(pos, i);
            std::transform(word.begin(), word.end(), word.begin(), [](unsigned char c){ return std::tolower(c); });
            if (keywords.count(word)) {
                result.push_back(keywords.at(word));
            } else {
                result.push_back({id, word});
            }

            pos += i - 1;
            continue;
        }
        // operators
        switch (input[pos]) {
            case '+': result.push_back({plus}); continue;
            case '-': result.push_back({minus}); continue;
            case '*': result.push_back({mul}); continue;
            case '(': result.push_back({lparen}); continue;
            case ')': result.push_back({rparen}); continue;
            // case '/': result.push_back({div_float}); continue;
        }
        throw std::runtime_error(std::string("Symbol '") + input[pos] + "' not eligible for tokenization");
    }
    return result;
}

/// @brief Searches for meaning in a stream of tokens
class Parser {
    std::vector<Token>::const_iterator current_token;
    std::vector<Token>::const_iterator end_token;

    typedef int64_t ParserNumber;

#pragma region AST
    struct AST {
        virtual ParserNumber visit() const = 0;
    };

    struct BinOp : AST {
        std::shared_ptr<AST> left;
        Token op;
        std::shared_ptr<AST> right;

        BinOp(std::shared_ptr<AST> left, Token op, std::shared_ptr<AST> right) : left(left), op(op), right(right) {}

        ParserNumber visit() const {
            switch (op.type) {
                case plus: return left->visit() + right->visit();
                case minus: return left->visit() - right->visit();
                case mul: return left->visit() * right->visit();
                case div_integer: return left->visit() / right->visit();
                default: return -1;
            }
        }
    };

    struct UnaryOp : AST {
        Token op;
        std::shared_ptr<AST> expr;

        UnaryOp(Token op, std::shared_ptr<AST> expr) : op(op), expr(expr) {}

        ParserNumber visit() const {
            switch (op.type) {
                case plus: return +expr->visit();
                case minus: return -expr->visit();
                default: return -1;
            }
        }
    };

    struct Num : AST {
        Token token;
        ParserNumber value;

        Num(Token token, ParserNumber value) : token(token), value(value) {}

        ParserNumber visit() const {
            return value;
        }
    };
#pragma endregion /* AST */

    void eat(TokenType expect) {
        if (current_token == end_token)
            throw std::runtime_error(std::string(TokenTypeString[expect]) + " expected and not found. I ran out of input!");
        if (current_token->type != expect)
            throw std::runtime_error(std::string(TokenTypeString[current_token->type]) + " != " + TokenTypeString[expect]);
        ++current_token;
    }

    std::shared_ptr<AST> factor() {
        const auto &token = *current_token;
        switch (token.type) {
            case plus:
            case minus: {
                eat(token.type);
                return std::make_shared<UnaryOp>(UnaryOp(token, factor()));
            } break;
            case integer: {
                eat(integer);
                return std::make_shared<Num>(Num{token, std::stoi(token.data.value())});
            }
            case lparen: {
                eat(lparen);
                const auto node = expr();
                eat(rparen);
                return node;
            } break;
            default: throw std::runtime_error("Failed to parse a factor");
        }
    }

    std::shared_ptr<AST> term() {
        auto node = factor();
        while (current_token->type == mul or current_token->type == div_integer) {
            const auto &token = *current_token;
            switch (token.type) {
                case mul: eat(mul); break;
                case div_integer: eat(div_integer); break;
            }
            node = std::make_shared<BinOp>(BinOp{node, token, factor()});
        }

        return node;
    }

    std::shared_ptr<AST> expr() {
        auto node = term();
        while (current_token->type == plus or current_token->type == minus) {
            const auto &token = *current_token;
            switch (token.type) {
                case plus: eat(plus); break;
                case minus: eat(minus); break;
            }
            node = std::make_shared<BinOp>(BinOp{node, token, term()});;
        }

        return node;
    }

public:
    Parser(std::vector<Token>::const_iterator start, std::vector<Token>::const_iterator end) : current_token(start), end_token(end) {}

    ParserNumber parse() {
        // expr is currently our start symbol
        auto tree = expr();
        return tree->visit();
    }
};

int main()
{
    const std::vector<Token> tokens = tokenize("5 - - - + - (3 + 4) - +2");
    std::cout << "Tokenizer result:" << std::endl;
    for (const Token& t : tokens) {
        std::cout << "\tType: " << TokenTypeString[t.type] << (t.data ? "; Data: \"" : "") << t.data.value_or("") << (t.data ? "\"" : "") << std::endl;
    }
    Parser parser(tokens.begin(), tokens.end());
    std::cout << "Parser result: " << parser.parse() << std::endl;
}
