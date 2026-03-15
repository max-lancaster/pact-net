using System;
using System.Threading.Tasks;

namespace PactNet.Extensions.Grpc;


/// <summary>
/// Grpc pact v4 builder
/// </summary>
public interface IGrpcPactBuilderV4: IPactBuilder, IDisposable
{
    /// <summary>
    /// Add a new interaction to the pact
    /// </summary>
    /// <param name="description">Interaction description</param>
    /// <returns>Fluent builder</returns>
    IGrpcRequestBuilderV4 UponReceiving(string description);
}

internal class GrpcPactBuilder : IGrpcPactBuilderV4
{
    private readonly ISynchronousPluginPactBuilderV4 pactBuilder;
    private ISynchronousPluginRequestBuilderV4 synchronousPluginRequestBuilder;
    private GrpcRequestBuilder requestBuilder;
    private bool interactionInitialized;

    /// <summary>
    /// Initialises a new instance of the <see cref="GrpcPactBuilder"/> class.
    /// </summary>
    internal GrpcPactBuilder(ISynchronousPluginPactBuilderV4 pactBuilder)
    {
        this.pactBuilder = pactBuilder;
    }

    /// <summary>
    /// Create a new request/response interaction
    /// </summary>
    /// <param name="description">Interaction description</param>
    /// <returns>Fluent builder</returns>
    public IGrpcRequestBuilderV4 UponReceiving(string description)
    {
        if (interactionInitialized)
        {
            throw new InvalidOperationException("An interaction has already been initialized for this pact.");
        }

        interactionInitialized = true;
        synchronousPluginRequestBuilder = pactBuilder.UponReceiving(description);
        requestBuilder = new GrpcRequestBuilder(synchronousPluginRequestBuilder);
        return requestBuilder;
    }

    /// <summary>
    /// <inheritdoc cref="Verify"/>
    /// </summary>
    public void Verify(Action<IConsumerContext> interact)
    {
        if (!interactionInitialized)
        {
            throw new InvalidOperationException("No pact has been initialized.");
        }

        this.synchronousPluginRequestBuilder.WithContent("application/grpc", requestBuilder.InteractionContents);
        this.pactBuilder.Verify(interact);
    }

    /// <summary>
    /// <inheritdoc cref="VerifyAsync"/>
    /// </summary>
    public async Task VerifyAsync(Func<IConsumerContext, Task> interact)
    {
        if (!interactionInitialized)
        {
            throw new InvalidOperationException("No pact has been initialized.");
        }

        this.synchronousPluginRequestBuilder.WithContent("application/grpc", requestBuilder.InteractionContents);
        await this.pactBuilder.VerifyAsync(interact);
    }

    public void Dispose() => this.pactBuilder.Dispose();
}
