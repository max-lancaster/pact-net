using System;
using System.IO;
using System.Text.Json;
using Moq;
using Xunit;
using Xunit.Abstractions;

namespace PactNet.Extensions.Grpc.Tests;

public class GrpcRequestBuilderTests(ITestOutputHelper testOutputHelper)
{
    [Fact]
    public void ConfiguresRequestAndResponse()
    {
        var builder = new GrpcRequestBuilder(new Mock<ISynchronousPluginRequestBuilderV4>().Object);
        string protoFilePath = Path.Combine("..", "..", "..", "..", "GrpcGreeterClient", "Protos", "greet.proto");
        string serviceName = "Greeter";
        string methodName = "SayHello";
        var content = $@"{{
                    ""pact:proto"":""{protoFilePath.Replace("\\", "\\\\")}"",
                    ""pact:proto-service"": ""{serviceName}/{methodName}"",
                    ""pact:content-type"": ""application/protobuf"",
                    ""request"": {{
                        ""name"": ""matching(type, 'foo')""
                    }},
                    ""response"": {{
                        ""message"": ""matching(type, 'Hello foo')""
                    }}
                }}".Replace(Environment.NewLine, "").Replace("'", "\\u0027");


        builder.WithRequest(protoFilePath, serviceName, methodName, new { name = "matching(type, 'foo')" })
            .WillRespond().WithBody(new { message = "matching(type, 'Hello foo')" });
        var actual = JsonSerializer.Serialize(builder.InteractionContents);
        testOutputHelper.WriteLine(actual);
        Assert.Equal(content, actual, ignoreAllWhiteSpace: true);
    }
}
