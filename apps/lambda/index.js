exports.handler = async (event) => {
  const response = {
      statusCode: 200,
      body: {"message": `Hello ${event.user?event.user:"there"}, welcome to Gloo Edge with Lambda.,`},
  };
  return response;
};
