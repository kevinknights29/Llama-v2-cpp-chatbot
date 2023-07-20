import chainlit as cl
from langchain.llms import LlamaCpp
from langchain import PromptTemplate, LLMChain
from langchain.callbacks.manager import CallbackManager
from langchain.callbacks.streaming_stdout import StreamingStdOutCallbackHandler


template = """Question: {question}

Answer: Let's think step by step."""

@cl.langchain_factory(use_async=False)
def factory():
    prompt = PromptTemplate(template=template, input_variables=["question"])
    
    # Callbacks support token-wise streaming
    callback_manager = CallbackManager([StreamingStdOutCallbackHandler()])
    # Verbose is required to pass to the callback manager
    
    # Make sure the model path is correct for your system!
    llm = LlamaCpp(
        model_path="/opt/models/llama-2-7b.ggmlv3.q4_0.bin",
        input={"temperature": 0.0, "max_length": 256, "top_p": 1, },
        callback_manager=callback_manager,
        verbose=True,
    )
    
    llm_chain = LLMChain(prompt=prompt, llm=llm)

    return llm_chain
