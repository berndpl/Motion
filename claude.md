# Motion App

+ See claude-technology.md for technology guidance and stack

Goal
Motion makes suggestions about your next steps and actions by generation actionable cards with content, purpose, insights and relevant action.

Information
The cards can be accessed in the app as a list
There is also a daily notifications extracting one item that stands out

Card
+ Each cards explains why it is relevant to you right now

How it works
+ Motion is connected to an LLM. For now it uses the REST interface of OLLAMA to process data

Input
+ A prompt "Create a short summary of the follwing content <spark content>" 
+ The combined content of all Spark files

Output
+ A Text response from the LLM

Interaction
+ When pressing the "Summarize" button the prompt and content is submited to Ollama via its REST API.
+ While it is processing the buttin becomes inactive and shows a spinner

## Notification

+ Add a notifications toggle to the options sheet
+ When enabled create a scheduled notification and run every hour showing the reponse as notifications text
+ Also add a test button to trigger the notififications manually for testing


Ollama


Functionality

Motion turns your Sparks you collected using the Spark app into actionable cards

A spark is based on something the user currently sees on the screen, similar to a bookmark
- A screenshot, captured with the native screen capture tool
- The current website in Safari
- A image

Motion can access Sparks stored in a shared iCloud Documents container

Motion turns spark into cards.

Something you might want to do next.

- Navigate to a place you stored
- Save a task to a reminder

Compass is a app native on Applle platforms

## Technology
- Always use SwiftUI
- Embracing the latest frameworks
- Suggest using new capabilities introduced lately e.g. during WWDC 2025
- Using Swift as programming language
- Add preview functionality to each view

Clean up
- Always check if there’s unused code to clean up and remove. Keep the code clean an consistent

Build
- Automatically run xcodebuild to test of the projects still builds and if there are any errors or warnings
- No need to ask before building the project. Just do it.

Animation
- Use implicit SwiftUI and SwiftData animation wherever possible. Don't add animation block unless implicit animation is not covering it


## Interface

### Main interface
1. Prompt textfield
2. Generate Button, native macOS button

##States

### Initial

+ Show textfield with prompt
+ Show "generate" button (secondary style)

### Processing

+ After tapping generate
+ turn button inactive
+ turn prompt textfield inactive
+ show spinner next to button

### Response

+ Replace the textfield content with prompt with the reponse
+ turn button into "Reset" button to return to initial state (secondary style) 

keep interface clean. With one textview and one button.

Hide the rest under a collabsable more section
