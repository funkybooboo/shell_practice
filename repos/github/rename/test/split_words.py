import re

# Function to load the dictionary from file
def load_dictionary(filename="dictionary.txt"):
    with open(filename, "r") as file:
        # Read each line and remove any extra spaces/newlines
        dictionary = [line.strip().lower() for line in file.readlines()]
    return dictionary

# Function to split repository name into dictionary words
def split_repo_name(repo_name, dictionary):
    result = []
    temp_name = repo_name.lower()  # Convert to lowercase for case-insensitive matching
    while temp_name:
        matched = False
        # Try matching the longest possible word from the start of the string
        for word in dictionary:
            if temp_name.startswith(word):
                result.append(word)  # If a match, add the word to result
                temp_name = temp_name[len(word):]  # Remove matched part from temp_name
                matched = True
                break  # Break the loop as we've found a match
        if not matched:
            # If no match is found, return an error
            print(f"Failed to match part of '{repo_name}'. Remaining string: '{temp_name}'")
            return None
    return "_".join(result)

# Main function to process and rename the repository
def main():
    # Load the dictionary from file
    dictionary = load_dictionary()

    # Example repo name (you can change this to any repo name you want to test)
    repo_name = "drawingirrationalnumbers"

    # Split the repository name based on the dictionary
    new_repo_name = split_repo_name(repo_name, dictionary)

    # Check if the name was successfully split
    if new_repo_name:
        print(f"Repository name '{repo_name}' was split and reformatted to '{new_repo_name}'.")
    else:
        print(f"Failed to split the repository name '{repo_name}'.")

if __name__ == "__main__":
    main()

