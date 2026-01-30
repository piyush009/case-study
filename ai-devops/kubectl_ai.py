"""
AI-Powered kubectl Command Generator

Converts natural language queries into kubectl commands using OpenAI.
This helps team members who are less familiar with kubectl syntax.
"""

import os

try:
    import openai
    OPENAI_AVAILABLE = True
except ImportError:
    OPENAI_AVAILABLE = False
    print("Warning: OpenAI not installed. Install with: pip install openai")


def generate_kubectl_command(user_query: str, api_key: str = None) -> str:
    """
    Generate kubectl command from natural language query.
    
    Args:
        user_query: Natural language description of what kubectl command is needed
        api_key: OpenAI API key (optional, can use OPENAI_API_KEY env var)
    
    Returns:
        Valid kubectl command string
    """
    if not OPENAI_AVAILABLE:
        return "# Error: OpenAI not installed. Run: pip install openai"
    
    if not api_key:
        api_key = os.getenv("OPENAI_API_KEY")
    
    if not api_key:
        return "# Error: OPENAI_API_KEY not set"
    
    openai.api_key = api_key
    
    try:
        response = openai.ChatCompletion.create(
            model="gpt-3.5-turbo",
            messages=[
                {
                    "role": "system",
                    "content": "You are a kubectl command generator. Return only valid kubectl commands, no explanations."
                },
                {
                    "role": "user",
                    "content": f"Convert to kubectl command: {user_query}"
                }
            ],
            max_tokens=100,
            temperature=0.3  # Lower temperature for more consistent output
        )
        
        command = response.choices[0].message.content.strip()
        # Remove markdown code blocks if present
        command = command.replace("```bash", "").replace("```", "").strip()
        
        return command
    except Exception as e:
        return f"# Error generating command: {str(e)}"


if __name__ == "__main__":
    # Example usage
    query = "show me all pods in ideas-api namespace"
    result = generate_kubectl_command(query)
    print(f"Query: {query}")
    print(f"Command: {result}")
