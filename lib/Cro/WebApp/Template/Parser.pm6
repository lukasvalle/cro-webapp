grammar Cro::WebApp::Template::Parser {
    token TOP {
        :my $*IN-ATTRIBUTE = False;
        <sequence-element>*
        [ $ || <.panic: 'confused'> ]
    }

    proto token sequence-element { * }

    token sequence-element:sym<sigil-tag> {
        <sigil-tag>
    }

    token sequence-element:sym<literal-text> {
        <-[<]>+
    }

    token sequence-element:sym<literal-open-tag> {
        :my $*IN-ATTRIBUTE = True;
        '<' <![/]> <!sigil>
        <tag-element>+
        [ '>' || <.panic: "malformed tag"> ]
    }

    token sequence-element:sym<literal-close-tag> {
        '</' <!sigil>
        <-[>]>+
        [ '>' || <.panic: "malformed closing tag"> ]
    }

    proto token tag-element { * }

    token tag-element:sym<sigil-tag> {
        <sigil-tag>
    }

    token tag-element:sym<literal> {
        <-[<>]>+
    }

    proto token sigil-tag { * }

    token sigil-tag:sym<topic> {
        '<.'
        <deref>
        [ '>' || <.panic: 'malformed topic tag'> ]
    }

    token sigil-tag:sym<iteration> {
        :my $*lone-start-line = False;
        '<@'
        [ <?after [^ | $ | \n] \h* '<@'> { $*lone-start-line = True } ]?
        [
        | <deref>
        ]
        [ \h* '>' || <.panic('malformed iteration tag')> ]
        [ <?{ $*lone-start-line }> [ \h* \n | { $*lone-start-line = False } ] ]?

        <sequence-element>*

        :my $*lone-end-line = False;
        '</@'
        [ <?after \n \h* '</@'> { $*lone-end-line = True } ]?
        <close-ident=.ident>?
        [ \h* '>' || <.panic('malformed iteration closing tag')> ]
        [ <?{ $*lone-end-line }> [ \h* \n | { $*lone-end-line = False } ] ]?
    }

    token sigil-tag:sym<condition> {
        :my $*lone-start-line = False;
        '<' $<negate>=<[?!]>
        [ <?after [^ | $ | \n] \h* '<' <[?!]>> { $*lone-start-line = True } ]?
        [
        | '.' <deref>
        ]
        [ \h* '>' || <.panic('malformed condition tag')> ]
        [ <?{ $*lone-start-line }> [ \h* \n | { $*lone-start-line = False } ] ]?

        <sequence-element>*

        :my $*lone-end-line = False;
        '</' $<negate>
        [ <?after \n \h* '</' <[?!]>> { $*lone-end-line = True } ]?
        <close-ident=.ident>?
        [ \h* '>' || <.panic('malformed conditional closing tag')> ]
        [ <?{ $*lone-end-line }> [ \h* \n | { $*lone-end-line = False } ] ]?
    }

    token sigil-tag:sym<call> {
        '<&'
        <target=.identifier>
        [ '>' || <.panic: 'malformed call tag'> ]
    }

    token sigil-tag:sym<sub> {
        :my $*lone-start-line = False;
        '<:sub'
        [ <?after [^ | $ | \n] \h* '<:sub'> { $*lone-start-line = True } ]?
        \h+
        [
        || <name=.identifier> \h*
           [ '(' \h* ')' \h* ]? '>'
        || <.panic('malformed sub declaration tag')>
        ]
        [ <?{ $*lone-start-line }> [ \h* \n | { $*lone-start-line = False } ] ]?

        <sequence-element>*

        :my $*lone-end-line = False;
        '</:'
        [ <?after \n \h* '</:'> { $*lone-end-line = True } ]?
        [ 'sub'? \h* '>' || <.panic('malformed sub declaration closing tag')> ]
        [ <?{ $*lone-end-line }> [ \h* \n | { $*lone-end-line = False } ] ]?
    }

    token sigil-tag:sym<use> {
        '<:use' \h+ <name=.single-quote-string> \h* '>' [\h* \n]?
        {
            my $used = $*TEMPLATE-REPOSITORY.resolve($<name>.ast);
        }
    }

    token deref {
        $<deref>=<.identifier>
    }

    token single-quote-string {
        "'" <( <-[']>* )> "'"
    }

    token sigil {
        # Single characters we can always take as a tag sigil
        | <[.$@&:]>
        # The ? and ! for boolification must be followed by a . or $ tag sigil;
        # <!DOCTYPE> and <?xml> style things must be considered literal.
        | <[?!]> <[.$>]>
    }

    token identifier {
        <.ident> [ <[-']> <.ident> ]*
    }

    method panic($reason) {
        die "Template parse failed: $reason near '" ~ self.orig.substr(self.pos, 40) ~ "'";
    }
}
