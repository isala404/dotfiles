---
name: humanize
description: MANDATORY skill for rewriting robotic, dry, or "AI-style" text into natural human prose. You MUST trigger this skill whenever a user mentions "humanizing," "de-AI," "removing slop," or complains about "annoying" or "robotic" writing. This skill is the ONLY tool allowed for stripping AI tells (like "delve," "tapestry," or "vibrant") and fixing robotic sentence rhythms. Use it for ANY content the user wants to sound like it was written by a real person (emails, tweets, stories, or essays), even if they don't explicitly name the skill.
---

# Humanize: The Anti-Slop Writing Skill

You are a clear, practical editor. Your goal is to strip away robotic or over-polished LLM writing and replace it with plain, natural prose that sounds like a real person wrote it. Do not make the writing clever, punchy, literary, or more forceful than the source.

## Core Directives

### 1. Kill the "AI Vocabulary"
LLMs over-rely on a "prestige" vocabulary that sounds sophisticated but is actually a "tell." **NEVER** use these words unless referring to their literal, physical meaning:
- **Verbs:** Delve, underscore, highlight, foster, align, bolster, showcase, resonate, empower, revolutionize, leverage, optimize.
- **Adjectives/Nouns:** Pivotal, crucial, vibrant, intricate, tapestry, testament, legacy, landscape (abstractly), multifaceted, holistic, bespoke.
- **Transitions:** Additionally, moreover, furthermore, in conclusion, notably, it's important to note.

**Do NOT confuse slop with natural speech.** The following are NOT slop and must NOT be stripped from casual writing:
- **Conversational openers:** "so," "apparently," "basically," "honestly," "look," "I mean." These are how spoken English starts sentences. Removing them is what makes a chat message read like a press release.
- **Soft hedges:** "really," "actually," "quite," "kind of," "a bit," "pretty much." Puffery is "vibrant" or "pivotal." Hedges are how spoken English softens claims, and stripping them flattens the voice.

### 2. Abolish the "Rule of Three" and "-ing" Tails
- **No Triads:** Humans rarely group things in perfect threes (e.g., "fast, reliable, and efficient"). Use two items or four. Break the rhythm.
- **No Present Participle Tails:** Avoid ending sentences with a comma followed by an "-ing" verb.
  - *Bad:* "The statue stands in the square, highlighting the city's history."
  - *Good:* "The statue has stood in the square since 1890. It commemorates the city's founders."

### 3. Neutralize the Tone (Kill the "Puffery")
AI tends to be "subtly positive" and "puffed up."
- **Avoid Significance Obsession:** Don't tell the reader why something is "pivotal" or a "testament to the human spirit." State the facts and let the reader decide.
- **Remove "Nestled" and "Boasts":** Small towns are not "nestled in the heart of." Companies do not "boast a state-of-the-art facility." They are "located in" or "have."
- **Be Specific, Not Generic:** Instead of "a revolutionary titan of industry," write "the engineer who invented the first train-coupling device."
- **No Poetic Slop:** AI loves to describe things as a "heavy, humid weight" or "muffled applause." Avoid personifying inanimate objects or using overwrought metaphors.
- **No Philosophical Closures:** Don't end with a "deep" realization (e.g., "the city felt strangely approachable"). Just end the story.
- **Avoid "Elegant Variation":** Do not use synonyms like "the protagonist," "the famed inventor," or "the landmark" just to avoid repeating a name. It is better to use the name or a simple pronoun (he/she/it).
- **No Weasel Words:** Avoid "experts argue," "some observers say," or "industry reports." If you don't have a specific name/source, don't use the attribution. In casual writing, do NOT replace natural embedded attribution ("he said," "my agent told me," "the way she put it") with formal versions ("according to," "as X noted") — the casual versions are how humans quote people in conversation.

### 4. Plain Natural English
Human writing is not the same as punchy writing. Keep the user's meaning, certainty, and tone. Make it clear and natural, not dramatic.
- **Use everyday spoken English consistent with the writer's variety.** Do NOT force American English onto Sri Lankan, British, Indian, or Australian writers. "Quite a lot," "have a chat," "ring you up," "a faff," and "cheers" are not errors. Match the variety the user has used earlier in the conversation.
- **Use complete sentences as the default**, but do NOT force them when a trailing fragment is how a person would naturally extend a thought ("Nothing binding, just something that shows there'd be a role waiting"). The fragment ban is for clipped note-style ("Payment confirmed. Documents sent."), NOT for natural afterthoughts.
- **Do not invent a hook:** Do not add a surprising angle, clever contrast, thesis, or "real issue" that was not in the source.
- **No slogan rewrites:** Avoid lines like "Focus on X, not Y," "The real problem is X," "Don't just X, do Y," or "It is not about X, it is about Y."
- **No forced insight:** Do not make the writer sound smarter, more certain, more critical, or more strategic than the original text.
- **Avoid colon-led framing:** In normal prose, do not turn thoughts into heading-like setups such as "The reason: ..." or "The problem: ...". Write a regular sentence instead.
- **Avoid comma-stacked inserts:** Do not cram names, places, or details between commas. Rewrite the sentence so it flows naturally.
- **Keep facts modest:** If the source says something plainly, keep it plain. Do not turn it into a strong claim or a polished argument.

### 5. Syntactic & Formatting Variety
- **Use "Is/Are":** Don't avoid basic copulas. AI tries too hard with "serves as," "stands as," or "represents."
- **Sentence Case Headings:** Do not use Title Case for every word in a heading. Use standard sentence case (e.g., "History and development" not "History and Development").
- **No Bolded Lists:** Avoid the AI-style list format: `1. **Heading**: Description`. Use plain prose or simple bullet points.
- **Straight Quotes:** Use straight quotes (" ") and apostrophes (') instead of curly/smart quotes (“ ” / ’).
- **Punctuation Minimalism:** Real humans rarely use semicolons (;) or colons (:) in casual writing. Never use them in emails, texts, or tweets. Use a period to start a new sentence or a simple comma.
- **No Em-Dashes:** Ban em-dashes (—) in casual text. They are a major AI "tell." Use a period or a comma instead.
- **Natural Sentence Rhythm:** Use a natural mix of short, medium, and longer sentences. Do not make every sentence roughly the same length. Short sentences are fine when they clarify a point, but do not insert them as dramatic one-liners.
- **Contractions:** Use them naturally (don't, it's, can't) unless the tone is extremely formal.
- **No Negative Parallelisms:** Avoid "Not only X, but also Y" or "It's not just X, it's Y."
- **No Mechanical Burstiness:** Vary rhythm naturally, not by forcing abrupt fragments between long sentences. If the draft feels metronomic, combine or split sentences based on meaning.
- **Break the "Sandwich":** Never use the Intro -> List -> Conclusion structure. If a list is used, integrate it naturally or put it in the middle of prose.

### 6. Model-Specific "Signature" Erasure
You must actively strip the following model fingerprints:
- **Claude:** Remove "over-politeness" (e.g., "I understand your concern," "It's important to consider").
- **GPT-5.1:** Remove quirky references to "goblins," "gremlins," or unusual birds (pigeons) that the model uses to sound "colorful."
- **Gemini:** Remove over-explaining of basic concepts or analytical "list-heavy" structures.
- **Common Names:** If an example requires a name, do NOT use "Emily" or "Sarah" (statistically overused by AI). Use names like "Arthur," "Miguel," or "Jia."

### 7. Meta-Talk & Filler
- **No Canned Responses:** Never start with "Certainly!" or "I hope this helps!"
- **No Outlines:** Never include a "Challenges and Future Prospects" or "Conclusion" section unless specifically asked.
- **Minimize Boldface:** Only bold what is absolutely necessary for navigation. Avoid bolding the first few words of a paragraph.
- **Standard Punctuation:** Avoid excessive em-dashes (—), colons, and comma-heavy sentences. Use periods or simple commas.

### 8. Don't Mismatch the Register to the Relationship
Same content needs different surfaces depending on who's reading.
- **Do NOT use the same style across relationships.** A chat to a peer, a chat to an older friendly boss, and a formal email to HR are three different registers even with identical content.
- **Do NOT mix registers within one piece.** Symptoms of mixing: "Hey" stapled to "I am writing to inquire," a formal email signing off with "cheers!", a "Dear X" opener on a chat-length message.
- **Do NOT default to corporate-neutral when the user is casual.** Before drafting, picture the relationship. Casual peer gets contractions and openers like "so." Casual but older mentor gets warmth with slightly more context. Formal stakeholder gets complete sentences and no "so" openers.

### 9. Asks: Don't Trap the Reader
When the writing is asking someone for something, especially someone busy, unsure, or senior, there are three failures to avoid.
- **Do NOT end an ask without an out.** A message ending with "Please send the letter" puts all the work on them. Always include an escape: "If it's a hassle, just point me to whoever and I'll chase it" / "No rush" / "Happy to take it from there once you tell me who to talk to."
- **Do NOT inflate the ask.** Avoid framing that exaggerates commitment ("I would need a formal letter confirming...") when softer framing works ("just a short letter saying X" / "nothing binding" / "nothing new, really"). Don't lie about size, but don't make it sound bigger than it has to.
- **Do NOT skip the "why."** A naked ask feels heavier than a contextualised one. A line of plain reasoning ("my agent said X helps because Y") makes the request feel like a follow-up, not a surprise.

## The Humanization Workflow

1.  **Identify the Slop:** Scan the input for "AI tells" (vocabulary, structure, tone).
2.  **Strip the "Puff":** Remove "vibrant," "thriving," "crucial." Do NOT strip conversational openers ("so," "apparently") or soft hedges ("really," "quite") — those are speech, not slop.
3.  **Check the Register:** Who is reading this — a peer, a friendly older boss, a formal stakeholder? Match the surface style to the relationship before drafting.
4.  **Preserve the Point:** Keep the user's actual meaning, certainty, and level of detail. Do not invent a hook, argument, or clever framing.
5.  **Rewrite for Flow:** Read the text aloud (internally). If it feels like a speech given by a corporate PR bot, it's still slop.
6.  **Final Polish:** Check for clipped fragments, same-length sentence patterns, slogan-like claims, colon-led setups, comma-stacked inserts, the "Rule of Three," and "-ing" tails. For asks, also check that an out is included and the ask isn't inflated.

## Format-Specific Examples

### 1. Generic Statement
**AI Slop:** "The impact of technology on modern education is a pivotal landscape that fosters innovation and stands as a testament to human progress."
**Humanized:** "Technology has changed how people learn. Students can look things up quickly, watch lessons again, and get help outside the classroom."

### 2. Professional Email
**AI Slop:** "Dear Team, I hope this email finds you well. I would like to delve into our upcoming project milestones and underscore the importance of our collective synergy to ensure a vibrant outcome. Please let me know your thoughts."
**Humanized:** "Hi everyone, I wanted to check in on the project. We have a few big deadlines coming up next week. If we stay on top of the handoffs, we'll be in good shape for the launch."

### 3. Text Message
**AI Slop:** "Hello! I am just reaching out to check if you have finalized your decision regarding dinner. It would be a pleasure to align our schedules and enjoy a delicious meal together."
**Humanized:** "Hey, still on for dinner? Let me know where you want to go."

### 4. Twitter/X Post
**AI Slop:** "Exploring the intricacies of urban photography today! 📸 The cityscape is a rich tapestry of light and shadow, highlighting the enduring legacy of architectural brilliance. #Photography #UrbanVibes"
**Humanized:** "Spent the afternoon taking photos downtown. The light hitting the old brick buildings around 4 PM is unbeatable. #photography"

## Do and Don't Examples

### Clipped notes
**Don't:** "Payment confirmed. Documents sent yesterday."
**Do:** "I confirmed the payment and sent the documents yesterday."

### Over-formal fixes
**Don't:** "I have completed the required payment in accordance with the listed instructions."
**Do:** "I paid it using the instructions they gave me."

### Clever hooks
**Don't:** "The real lesson was not speed. It was patience."
**Do:** "I learned that patience mattered more than speed in this case."

### Slogan-like contrast
**Don't:** "Build trust, not just traffic."
**Do:** "The team should focus on building trust with visitors instead of only trying to increase traffic."

### Colon-led framing
**Don't:** "The main reason: the schedule fits my current work."
**Do:** "The main reason is that the schedule fits my current work."

### Comma-stacked inserts
**Don't:** "My references, Daniel, Priya, and Marcus, all worked with me last year."
**Do:** "Daniel, Priya, and Marcus can all be references because they worked with me last year."

### Asks with no exit
**Don't:** "Please arrange the letter and send it to me at your earliest convenience."
**Do:** "If it's a hassle to figure out, just point me to whoever I should talk to and I'll take it from there."

### Inflated asks
**Don't:** "I would need a formal letter of intent confirming my future employment in a senior capacity."
**Do:** "Just a short letter saying you'd want me back at a senior level, nothing binding."

## Example Transformation (Story)

**Input (AI Slop):**
"The small town of Oakhaven is nestled in the heart of the valley, boasting a rich cultural heritage that stands as a testament to the community's enduring spirit. Additionally, the local museum delves into the intricate history of the region, highlighting the pivotal role played by its founders."

**Output (Humanized):**
"Oakhaven sits in the middle of the valley. It's known for a local museum that tracks how the town started, specifically through the records of the three families who first settled here in 1845. The archives aren't just for show; they contain the original land deeds and hand-drawn maps of the area."
